# --- Initialization ---

struct InitCoordination2GroupsSystem <: System end

function initialize!(::InitCoordination2GroupsSystem, world::World)
    params = get_resource(world, Coordination2GroupsParams)
    rng = get_resource(world, RNGResource).rng
    stats = get_resource(world, Coordination2GroupsStats)

    n_norm1 = 0
    for x in 1:params.grid_width, y in 1:params.grid_height
        x == params.border_x && continue
        group = x < params.border_x ? 0 : 1
        init_prob = group == 0 ? params.init_norm1_groupA : params.init_norm1_groupB
        has_norm = rand(rng) < init_prob
        new_entity!(world, (
            Coord2GroupID(group),
            Coord2Norm1(has_norm),
            Coord2Payoff(0.0),
        ))
        if has_norm
            n_norm1 += 1
        end
    end
    stats.n_norm1 = n_norm1
    return nothing
end

# --- Calculate Payoffs ---

struct Coord2CalculatePayoffsSystem <: System end

function update!(::Coord2CalculatePayoffsSystem, world::World)
    params = get_resource(world, Coordination2GroupsParams)

    # Count turtles and norm1 per group
    count_0 = 0; count_1 = 0
    norm1_0 = 0; norm1_1 = 0
    for (_, groups, norms) in Query(world, (Coord2GroupID, Coord2Norm1))
        @inbounds for i in eachindex(groups)
            if groups[i].id == 0
                count_0 += 1
                if norms[i].has_norm; norm1_0 += 1; end
            else
                count_1 += 1
                if norms[i].has_norm; norm1_1 += 1; end
            end
        end
    end

    num_agents = (count_0 + count_1) / 2.0

    p1_0 = norm1_0 / num_agents
    norm1_payoff_0 = p1_0 * (1 + params.norm1_prosocial_benefit + params.norm1_coord_benefit) +
                     (1 - p1_0) * (1 - params.norm1_rarity_cost)
    norm2_payoff_0 = p1_0 * (1 + params.norm1_prosocial_benefit) + (1 - p1_0) * 1.0

    p1_1 = norm1_1 / num_agents
    norm1_payoff_1 = p1_1 * (1 + params.norm1_prosocial_benefit + params.norm1_coord_benefit) +
                     (1 - p1_1) * (1 - params.norm1_rarity_cost)
    norm2_payoff_1 = p1_1 * (1 + params.norm1_prosocial_benefit) + (1 - p1_1) * 1.0

    for (_, groups, norms, payoffs) in Query(world, (Coord2GroupID, Coord2Norm1, Coord2Payoff))
        @inbounds for i in eachindex(groups)
            if groups[i].id == 0
                payoffs[i].value = norms[i].has_norm ? norm1_payoff_0 : norm2_payoff_0
            else
                payoffs[i].value = norms[i].has_norm ? norm1_payoff_1 : norm2_payoff_1
            end
        end
    end
    return nothing
end

# --- Evolve ---
# NetLogo: ask turtles [ pick model from own/other group, copy norm with Fermi probability ]

struct Coord2EvolveSystem <: System end

function update!(::Coord2EvolveSystem, world::World)
    params = get_resource(world, Coordination2GroupsParams)
    rng = get_resource(world, RNGResource).rng

    # Snapshot all entities into parallel vectors
    all_eids = Entity[]
    all_groups = Int[]
    all_norms = Bool[]
    all_payoffs = Float64[]
    for (eids, groups, norms, payoffs) in Query(world, (Coord2GroupID, Coord2Norm1, Coord2Payoff))
        @inbounds for i in eachindex(eids)
            push!(all_eids, eids[i])
            push!(all_groups, groups[i].id)
            push!(all_norms, norms[i].has_norm)
            push!(all_payoffs, payoffs[i].value)
        end
    end

    n = length(all_eids)
    group0_idx = [i for i in 1:n if all_groups[i] == 0]
    group1_idx = [i for i in 1:n if all_groups[i] == 1]
    group_indices = (group0_idx, group1_idx)  # tuple indexed by groupID+1

    order = randperm(rng, n)
    for idx in order
        myID = all_groups[idx]
        my_payoff = all_payoffs[idx]

        otherID = myID
        if rand(rng) < params.prob_outgroup_observation
            otherID = (myID + 1) % 2
        end

        target = group_indices[otherID + 1]
        # "other turtles" excludes self
        model_i = target[rand(rng, 1:length(target))]
        while model_i == idx && length(target) > 1
            model_i = target[rand(rng, 1:length(target))]
        end
        model_i == idx && continue

        model_payoff = all_payoffs[model_i]
        model_norm = all_norms[model_i]

        prob_copy = 1.0 / (1.0 + exp(-(model_payoff - my_payoff)))
        if rand(rng) < prob_copy
            all_norms[idx] = model_norm
            get_components(world, all_eids[idx], (Coord2Norm1,))[1].has_norm = model_norm
        end
    end
    return nothing
end

# --- Termination ---

struct Coordination2GroupsTerminationSystem <: System end

function update!(::Coordination2GroupsTerminationSystem, world::World)
    params = get_resource(world, Coordination2GroupsParams)
    stats = get_resource(world, Coordination2GroupsStats)
    tick = get_resource(world, Tick)

    n_norm1 = 0
    n_total = 0
    for (_, norms) in Query(world, (Coord2Norm1,))
        @inbounds for i in eachindex(norms)
            n_total += 1
            if norms[i].has_norm
                n_norm1 += 1
            end
        end
    end
    stats.n_norm1 = n_norm1

    if n_norm1 == n_total || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
