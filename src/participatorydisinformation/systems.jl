# Participatory Disinformation – ECS systems
# Rumor spreading on network with elite exposure and bitstring-based rumor tracking

struct InitPDisinfoSystem <: System end

function _pdisinfo_build_ba!(net::PDisinfoNetwork, rng, n::Int, max_rumors::Int)
    # Start with 2 connected nodes
    _pdisinfo_add_agent!(net, max_rumors)
    _pdisinfo_add_agent!(net, max_rumors)
    _pdisinfo_add_edge!(net, 1, 2)
    # Each new node connects to 1 existing (preferential attachment)
    for _ in 3:n
        new_id = _pdisinfo_add_agent!(net, max_rumors)
        total_degree = sum(net.degree[k] for k in 1:(new_id - 1))
        if total_degree == 0
            target = rand(rng, 1:(new_id - 1))
        else
            r = rand(rng) * total_degree
            cumulative = 0.0
            target = 1
            for j in 1:(new_id - 1)
                cumulative += net.degree[j]
                if cumulative >= r
                    target = j
                    break
                end
            end
        end
        _pdisinfo_add_edge!(net, new_id, target)
    end
end

function initialize!(::InitPDisinfoSystem, world::World)
    params = get_resource(world, PDisinfoParams)
    rng    = get_resource(world, RNGResource).rng
    net    = get_resource(world, PDisinfoNetwork)

    n_total = params.num_people + 1   # last agent is the elite
    _pdisinfo_build_ba!(net, rng, n_total, params.max_rumors)

    elite_id = n_total
    net.agent_type[elite_id] = 2

    # Assign influencers among non-elite agents
    n_influencers = max(1, round(Int, params.num_people * params.frac_influencers))
    indices = Random.shuffle(rng, collect(1:params.num_people))
    for k in 1:n_influencers
        net.agent_type[indices[k]] = 1
    end

    # Elite starts with 1 random rumor
    rumor_idx = rand(rng, 1:params.max_rumors)
    net.rumors[elite_id][rumor_idx] = true
    return nothing
end

# --- Main go procedure ---

struct PDisinfoGoSystem <: System end

function update!(::PDisinfoGoSystem, world::World)
    params   = get_resource(world, PDisinfoParams)
    rng      = get_resource(world, RNGResource).rng
    net      = get_resource(world, PDisinfoNetwork)
    stats    = get_resource(world, PDisinfoStats)
    elite_id = params.num_people + 1

    # Process each non-elite agent in random order
    order = Random.shuffle(rng, collect(1:params.num_people))
    for i in order
        # 1. Adopt from elite
        if rand(rng) < params.elite_influence
            novel = net.rumors[elite_id] .& .!net.rumors[i]
            if any(novel)
                novel_idx = findall(novel)
                chosen = novel_idx[rand(rng, 1:length(novel_idx))]
                net.rumors[i][chosen] = true
                stats.times_heard_from_elites += 1
            end
        end

        # 2. Adopt from network neighbours
        neighbors = net.adj[i]
        total_neighbors = length(neighbors)
        if total_neighbors > 0
            adopted_nbrs = Int[]
            for j in neighbors
                if any(net.rumors[j])
                    push!(adopted_nbrs, j)
                end
            end
            frac = length(adopted_nbrs) / total_neighbors
            if frac > 0.0 && rand(rng) < params.social_influence * frac
                source = adopted_nbrs[rand(rng, 1:length(adopted_nbrs))]
                novel = net.rumors[source] .& .!net.rumors[i]
                if any(novel)
                    novel_idx = findall(novel)
                    chosen = novel_idx[rand(rng, 1:length(novel_idx))]
                    net.rumors[i][chosen] = true
                    stats.times_heard_from_social += 1
                end
            end
        end

        # 3. Generate rumor
        if rand(rng) < params.rumor_generation
            idx = rand(rng, 1:params.max_rumors)
            if !net.rumors[i][idx]
                net.rumors[i][idx] = true
                stats.times_created_rumor += 1
            end
        end

        # 4. Forget rumor
        if rand(rng) < params.dissipation_rate
            my_true = findall(net.rumors[i])
            if !isempty(my_true)
                idx = my_true[rand(rng, 1:length(my_true))]
                net.rumors[i][idx] = false
            end
        end
    end

    # 5. Trade-up: influencer → elite
    if rand(rng) < params.trade_up_influence
        influencer_ids = findall(==(1), net.agent_type)
        if !isempty(influencer_ids)
            source = influencer_ids[rand(rng, 1:length(influencer_ids))]
            novel = net.rumors[source] .& .!net.rumors[elite_id]
            if any(novel)
                novel_idx = findall(novel)
                chosen = novel_idx[rand(rng, 1:length(novel_idx))]
                net.rumors[elite_id][chosen] = true
                stats.times_traded_up += 1
            end
        end
    end
    return nothing
end

# --- Termination ---

struct PDisinfoTerminationSystem <: System end

function update!(::PDisinfoTerminationSystem, world::World)
    params = get_resource(world, PDisinfoParams)
    tick   = get_resource(world, Tick)
    net    = get_resource(world, PDisinfoNetwork)

    # All non-elite agents heard all rumors?
    all_heard = true
    for i in 1:params.num_people
        if !all(net.rumors[i])
            all_heard = false
            break
        end
    end

    if all_heard || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
