# Participatory Disinfo (simplified) — preferential attachment + uniform elite

struct InitPDisSystem <: System end

function initialize!(::InitPDisSystem, world::World)
    params = get_resource(world, PDisParams)
    rng    = get_resource(world, RNGResource).rng
    net    = get_resource(world, PDisNetwork)
    stats  = get_resource(world, PDisStats)

    # Build preferential attachment network
    g = nw_generate_preferential_attachment(rng, params.num_people, params.min_size)
    for i in 1:g.n; _pdis_add_agent!(net, params.max_rumors); end
    net.adj[1:g.n] = g.adj

    # Assign influencers
    n_inf = max(1, round(Int, params.frac_influencers * params.num_people))
    indices = shuffle!(rng, collect(1:params.num_people))
    for k in 1:n_inf
        net.agent_type[indices[k]] = 1
    end

    # Create elite
    elite_id = _pdis_add_agent!(net, params.max_rumors)
    net.agent_type[elite_id] = 2
    rumor_idx = rand(rng, 1:params.max_rumors)
    net.rumors[elite_id][rumor_idx] = true

    # Uniform variant: all patches vote=1, so elite_adoption = elite_influence always
    stats.times_heard_from_elites = 0
    stats.times_heard_from_social = 0
    stats.times_traded_up = 0
    stats.times_created_rumor = 0
    return nothing
end

function _pdis_adopt_rumor(my_rumors::BitVector, other_rumors::BitVector, rng)
    novel = other_rumors .& .!my_rumors
    if any(novel)
        novel_idx = findall(novel)
        chosen = novel_idx[rand(rng, 1:length(novel_idx))]
        result = copy(my_rumors)
        result[chosen] = true
        return result
    end
    return my_rumors
end

struct PDisGoSystem <: System end

function update!(::PDisGoSystem, world::World)
    params   = get_resource(world, PDisParams)
    rng      = get_resource(world, RNGResource).rng
    net      = get_resource(world, PDisNetwork)
    stats    = get_resource(world, PDisStats)
    tick     = get_resource(world, Tick)
    elite_id = net.n_total

    if tick.tick % params.model_rate_1_nth != 0
        return nothing
    end

    order = shuffle!(rng, collect(1:params.num_people))
    for i in order
        # 1. Adopt from elite (uniform: always full elite_influence)
        if rand(rng) < params.elite_influence
            new_rumors = _pdis_adopt_rumor(net.rumors[i], net.rumors[elite_id], rng)
            if new_rumors != net.rumors[i]
                net.rumors[i] = new_rumors
                stats.times_heard_from_elites += 1
            end
        end

        # 2. Adopt from network
        neighbors = net.adj[i]
        total_nbrs = length(neighbors)
        if total_nbrs > 0
            adopted_nbrs = [j for j in neighbors if any(net.rumors[j])]
            frac = length(adopted_nbrs) / total_nbrs
            if frac > 0.0 && rand(rng) < params.social_influence * frac
                source = adopted_nbrs[rand(rng, 1:length(adopted_nbrs))]
                new_rumors = _pdis_adopt_rumor(net.rumors[i], net.rumors[source], rng)
                if new_rumors != net.rumors[i]
                    net.rumors[i] = new_rumors
                    stats.times_heard_from_social += 1
                end
            end
        end

        # 3. Generate rumor
        if !params.only_one_generates || rand(rng, 0:(params.num_people-1)) == i - 1
            if net.agent_type[i] != 1 || params.influencers_generate_rumors
                if !params.heard_rumors_to_generate || any(net.rumors[i])
                    if rand(rng) < params.rumor_generation
                        pos = rand(rng, 1:params.max_rumors)
                        if !net.rumors[i][pos]
                            net.rumors[i][pos] = true
                            stats.times_created_rumor += 1
                        end
                    end
                end
            end
        end

        # 4. Forget rumor
        if !params.only_one_forgets || rand(rng, 0:(params.num_people-1)) == i - 1
            if rand(rng) < params.dissipation_rate
                pos = rand(rng, 1:params.max_rumors)
                net.rumors[i][pos] = false
            end
        end
    end

    # 5. Trade-up
    influencer_ids = findall(==(1), net.agent_type)
    if !isempty(influencer_ids) && rand(rng) < params.trade_up_influence
        source = influencer_ids[rand(rng, 1:length(influencer_ids))]
        new_rumors = _pdis_adopt_rumor(net.rumors[elite_id], net.rumors[source], rng)
        if new_rumors != net.rumors[elite_id]
            net.rumors[elite_id] = new_rumors
            stats.times_traded_up += 1
        end
    end

    return nothing
end

struct PDisTerminationSystem <: System end

function update!(::PDisTerminationSystem, world::World)
    params = get_resource(world, PDisParams)
    tick   = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
