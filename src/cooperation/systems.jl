# --- Initialization ---

struct InitCOOPSystem <: System end

function initialize!(::InitCOOPSystem, world::World)
    params = get_resource(world, COOPParams)
    rng = get_resource(world, RNGResource).rng
    grass_grid = get_resource(world, COOPGrassGrid)
    w, h = grass_grid.width, grass_grid.height

    # Initialize all patches to max grass height
    for x in 1:w, y in 1:h
        grass_grid.grass[x, y] = params.max_grass_height
    end

    # Create cows with random continuous positions
    for _ in 1:params.initial_cows
        cx = rand(rng) * w
        cy = rand(rng) * h
        e = params.metabolism * 4.0
        is_coop = rand(rng) < params.cooperative_probability
        new_entity!(world, (
            COOPPosition(cx, cy),
            COOPCowType(is_coop),
            COOPEnergy(e),
        ))
    end

    # Compute initial stats
    _coop_update_stats!(world)
    return nothing
end

function _coop_update_stats!(world::World)
    stats = get_resource(world, COOPStats)
    nc = 0
    ng = 0
    for (_, _, cow_types) in Query(world, (COOPPosition, COOPCowType))
        @inbounds for i in eachindex(cow_types)
            if cow_types[i].cooperative
                nc += 1
            else
                ng += 1
            end
        end
    end
    stats.num_cooperative = nc
    stats.num_greedy = ng
    stats.total_cows = nc + ng
    return nothing
end

# --- Main Go System ---

mutable struct COOPGoSystem <: System
    new_cows::Vector{Tuple{Float64, Float64, Bool, Float64}}  # x, y, cooperative, energy
end
COOPGoSystem() = COOPGoSystem(Tuple{Float64, Float64, Bool, Float64}[])

function update!(system::COOPGoSystem, world::World)
    params = get_resource(world, COOPParams)
    rng = get_resource(world, RNGResource).rng
    grass_grid = get_resource(world, COOPGrassGrid)
    w, h = grass_grid.width, grass_grid.height

    empty!(system.new_cows)
    to_remove = Entity[]

    # --- Ask turtles (shuffled): move, eat, reproduce ---
    all_indices = Tuple{Entity, Int}[]
    archetype_data = collect(Query(world, (COOPPosition, COOPCowType, COOPEnergy)))
    for (eids, positions, cow_types, energies) in archetype_data
        for i in eachindex(positions)
            push!(all_indices, (eids[i], i))
        end
    end
    Random.shuffle!(rng, all_indices)

    # Build lookup from entity to archetype data
    eid_to_arch = Dict{Entity, Tuple{Int, Int}}()
    for (arch_idx, (eids, _, _, _)) in enumerate(archetype_data)
        for i in eachindex(eids)
            eid_to_arch[eids[i]] = (arch_idx, i)
        end
    end

    for (eid, _) in all_indices
        !is_alive(world, eid) && continue
        arch_idx, i = eid_to_arch[eid]
        (_, positions, cow_types, energies) = archetype_data[arch_idx]

        pos = positions[i]
        cow_type = cow_types[i]
        energy = energies[i]

        # Move: rt random 360, fd stride-length (NetLogo heading model)
        heading = rand(rng) * 360.0
        θ = deg2rad(heading)
        pos.x = mod(pos.x + sin(θ) * params.stride_length, Float64(w))
        pos.y = mod(pos.y + cos(θ) * params.stride_length, Float64(h))

        # Lose energy
        energy.energy -= params.metabolism

        # Die if energy < 0
        if energy.energy < 0.0
            push!(to_remove, eid)
            continue
        end

        # Eat: lookup grass at current patch
        gx = clamp(floor(Int, pos.x) + 1, 1, w)
        gy = clamp(floor(Int, pos.y) + 1, 1, h)
        current_grass = grass_grid.grass[gx, gy]

        if cow_type.cooperative
            # Cooperative: only eat if grass > low_high_threshold
            if current_grass > params.low_high_threshold
                grass_grid.grass[gx, gy] -= 1
                energy.energy += params.grass_energy
            end
        else
            # Greedy: eat if grass > 0
            if current_grass > 0
                grass_grid.grass[gx, gy] -= 1
                energy.energy += params.grass_energy
            end
        end

        # Reproduce: if energy > reproduction_threshold
        if energy.energy > params.reproduction_threshold
            energy.energy -= params.reproduction_cost
            # Hatch 1: child gets parent's current (post-cost) energy and same position/breed
            push!(system.new_cows, (pos.x, pos.y, cow_type.cooperative, energy.energy))
        end
    end

    # Remove dead cows
    for e in to_remove
        is_alive(world, e) && remove_entity!(world, e)
    end

    # Spawn offspring
    for (cx, cy, is_coop, e) in system.new_cows
        new_entity!(world, (
            COOPPosition(cx, cy),
            COOPCowType(is_coop),
            COOPEnergy(e),
        ))
    end

    # --- Ask patches: grow grass ---
    for x in 1:w, y in 1:h
        g = grass_grid.grass[x, y]
        if g >= params.low_high_threshold
            if params.high_growth_chance >= rand(rng) * 100.0
                g += 1
            end
        else
            if params.low_growth_chance >= rand(rng) * 100.0
                g += 1
            end
        end
        if g > params.max_grass_height
            g = params.max_grass_height
        end
        grass_grid.grass[x, y] = g
    end

    # Update population stats
    _coop_update_stats!(world)
    return nothing
end

# --- Termination ---

struct COOPTerminationSystem <: System end

function update!(::COOPTerminationSystem, world::World)
    stats = get_resource(world, COOPStats)
    params = get_resource(world, COOPParams)
    tick = get_resource(world, Tick)

    if stats.total_cows == 0 || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
