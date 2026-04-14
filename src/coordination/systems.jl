# --- Initialization ---

struct InitCoordSystem <: System end

function initialize!(::InitCoordSystem, world::World)
    params = get_resource(world, CoordinationParams)
    rng = get_resource(world, RNGResource).rng
    stats = get_resource(world, CoordStats)

    # One turtle per patch
    for x in 1:params.grid_size, y in 1:params.grid_size
        is_norm1 = rand(rng) < params.init_norm1
        new_entity!(world, (
            CoordPosition(x, y),
            CoordNorm(is_norm1),
            CoordPayoff(0.0),
        ))
    end

    # Initial count
    n1 = 0
    for (_, _, norms) in Query(world, (CoordPosition, CoordNorm))
        @inbounds for i in eachindex(norms)
            norms[i].norm1 && (n1 += 1)
        end
    end
    stats.n_norm1 = n1
    return nothing
end

# --- Calculate Payoffs ---

struct CalcPayoffsSystem <: System end

function update!(::CalcPayoffsSystem, world::World)
    params = get_resource(world, CoordinationParams)

    # Count norm1 agents
    total = 0
    n1 = 0
    for (_, _, norms) in Query(world, (CoordPosition, CoordNorm))
        @inbounds for i in eachindex(norms)
            total += 1
            norms[i].norm1 && (n1 += 1)
        end
    end

    total == 0 && return nothing
    p1 = n1 / total
    norm1_payoff = 1.0 + p1 * params.coordination_benefit
    norm2_payoff = 1.0 + (1.0 - p1) * params.coordination_benefit

    for (_, _, norms, payoffs) in Query(world, (CoordPosition, CoordNorm, CoordPayoff))
        @inbounds for i in eachindex(norms)
            payoffs[i].value = norms[i].norm1 ? norm1_payoff : norm2_payoff
        end
    end
    return nothing
end

# --- Evolve (Fermi imitation, sequential with immediate updates) ---

struct EvolveSystem <: System end

function update!(::EvolveSystem, world::World)
    rng = get_resource(world, RNGResource).rng

    # Collect all entity IDs
    all_entities = Entity[]
    for (eids, _) in Query(world, (CoordPosition,))
        append!(all_entities, eids)
    end

    n = length(all_entities)
    n <= 1 && return nothing

    # Shuffle for NetLogo-style `ask turtles`
    for i in n:-1:2
        j = rand(rng, 1:i)
        all_entities[i], all_entities[j] = all_entities[j], all_entities[i]
    end

    # Process each turtle sequentially (immediate updates)
    for idx in 1:n
        eid = all_entities[idx]
        !is_alive(world, eid) && continue

        my_norm, my_payoff = get_components(world, eid, (CoordNorm, CoordPayoff))

        # Pick a random model from all OTHER turtles
        model_eid = eid
        while model_eid == eid
            model_eid = all_entities[rand(rng, 1:n)]
        end
        !is_alive(world, model_eid) && continue

        model_norm, model_payoff = get_components(world, model_eid, (CoordNorm, CoordPayoff))

        # Only consider copying if different norm
        model_norm.norm1 == my_norm.norm1 && continue

        # Fermi function: probability of copying
        prob_copy = 1.0 / (1.0 + exp(-(model_payoff.value - my_payoff.value)))
        if rand(rng) < prob_copy
            my_norm.norm1 = model_norm.norm1
        end
    end
    return nothing
end

# --- Statistics ---

struct CoordStatsSystem <: System end

function update!(::CoordStatsSystem, world::World)
    stats = get_resource(world, CoordStats)
    n1 = 0
    for (_, _, norms) in Query(world, (CoordPosition, CoordNorm))
        @inbounds for i in eachindex(norms)
            norms[i].norm1 && (n1 += 1)
        end
    end
    stats.n_norm1 = n1
    return nothing
end

# --- Termination ---

struct CoordTerminationSystem <: System end

function update!(::CoordTerminationSystem, world::World)
    params = get_resource(world, CoordinationParams)
    tick = get_resource(world, Tick)
    stats = get_resource(world, CoordStats)

    total = params.grid_size * params.grid_size
    # Stop if all same norm or max ticks reached
    if stats.n_norm1 == total || stats.n_norm1 == 0 || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
