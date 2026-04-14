# Rabbits Grass Weeds systems
# Matches NetLogo execution order:
#   grow-grass-and-weeds
#   ask rabbits [ move; eat-grass; eat-weeds; reproduce; death ]

# --- Initialization ---

struct InitRGWSystem <: System end

function initialize!(::InitRGWSystem, world::World)
    params = get_resource(world, RGWParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, RGWPatchGrid)
    w, h = grid.width, grid.height

    # Grow initial grass and weeds on all patches
    for x in 1:w, y in 1:h
        if rand(rng) * 1000.0 < params.weeds_grow_rate
            grid.patches[x, y] = RGW_WEEDS
        end
        if rand(rng) * 1000.0 < params.grass_grow_rate
            grid.patches[x, y] = RGW_GRASS
        end
    end

    # Create rabbits with random positions and energy 0..9
    for _ in 1:params.number
        x = rand(rng) * w
        y = rand(rng) * h
        e = Float64(rand(rng, 0:9))
        heading = Float64(rand(rng, 0:359))
        new_entity!(world, (RGWPosition(x, y), RGWHeading(heading), RGWEnergy(e)))
    end

    # Compute initial stats
    stats = get_resource(world, RGWStats)
    stats.num_rabbits = params.number
    _rgw_count_patches!(stats, grid)
    return nothing
end

# --- Main Go System ---

mutable struct RGWGoSystem <: System
    new_rabbits::Vector{Tuple{Float64, Float64, Float64, Float64}}  # x, y, energy, heading
end
RGWGoSystem() = RGWGoSystem(Tuple{Float64,Float64,Float64,Float64}[])

function update!(system::RGWGoSystem, world::World)
    params = get_resource(world, RGWParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, RGWPatchGrid)
    stats = get_resource(world, RGWStats)
    w, h = grid.width, grid.height

    # Check if any rabbits exist; if not, stop
    rabbit_count = 0
    for (eids, _) in Query(world, (RGWPosition,))
        rabbit_count += length(eids)
    end
    if rabbit_count == 0
        get_resource(world, Terminate).stop = true
        stats.num_rabbits = 0
        _rgw_count_patches!(stats, grid)
        return nothing
    end

    # Grow grass and weeds on empty patches
    for x in 1:w, y in 1:h
        if grid.patches[x, y] == RGW_EMPTY
            if rand(rng) * 1000.0 < params.weeds_grow_rate
                grid.patches[x, y] = RGW_WEEDS
            end
            if rand(rng) * 1000.0 < params.grass_grow_rate
                grid.patches[x, y] = RGW_GRASS
            end
        end
    end

    # Ask rabbits (shuffled): move, eat-grass, eat-weeds, reproduce, death
    empty!(system.new_rabbits)
    to_remove = Entity[]

    for (eids, positions, headings, energies) in Query(world, (RGWPosition, RGWHeading, RGWEnergy))
        indices = collect(eachindex(positions))
        Random.shuffle!(rng, indices)
        @inbounds for i in indices
            pos = positions[i]
            hdg = headings[i]
            eng = energies[i]

            # Move: rt random 50; lt random 50; fd 1; energy -= 0.5
            hdg.heading += Float64(rand(rng, 0:49))
            hdg.heading -= Float64(rand(rng, 0:49))
            θ = deg2rad(hdg.heading)
            pos.x = mod(pos.x + sin(θ), Float64(w))
            pos.y = mod(pos.y + cos(θ), Float64(h))
            eng.energy -= 0.5

            # Patch lookup: round to nearest grid cell (1-indexed)
            gx = clamp(floor(Int, pos.x) + 1, 1, w)
            gy = clamp(floor(Int, pos.y) + 1, 1, h)

            # Eat grass
            if grid.patches[gx, gy] == RGW_GRASS
                grid.patches[gx, gy] = RGW_EMPTY
                eng.energy += params.grass_energy
            end

            # Eat weeds
            if grid.patches[gx, gy] == RGW_WEEDS
                grid.patches[gx, gy] = RGW_EMPTY
                eng.energy += params.weed_energy
            end

            # Reproduce: if energy > threshold, energy /= 2, hatch 1 [fd 1]
            if eng.energy > params.birth_threshold
                eng.energy /= 2.0
                push!(system.new_rabbits, (pos.x, pos.y, eng.energy, hdg.heading))
            end

            # Death: if energy < 0, die
            if eng.energy < 0.0
                push!(to_remove, eids[i])
            end
        end
    end

    # Remove dead rabbits
    for e in to_remove
        is_alive(world, e) && remove_entity!(world, e)
    end

    # Spawn offspring — NetLogo: hatch 1 [fd 1]
    for (x, y, e, h_angle) in system.new_rabbits
        θ = deg2rad(h_angle)
        nx = mod(x + sin(θ), Float64(w))
        ny = mod(y + cos(θ), Float64(h))
        new_entity!(world, (RGWPosition(nx, ny), RGWHeading(h_angle), RGWEnergy(e)))
    end

    # Update stats
    new_count = 0
    for (eids, _) in Query(world, (RGWPosition,))
        new_count += length(eids)
    end
    stats.num_rabbits = new_count
    _rgw_count_patches!(stats, grid)
    return nothing
end

function _rgw_count_patches!(stats::RGWStats, grid::RGWPatchGrid)
    grass = 0
    weeds = 0
    for x in 1:grid.width, y in 1:grid.height
        p = grid.patches[x, y]
        if p == RGW_GRASS
            grass += 1
        elseif p == RGW_WEEDS
            weeds += 1
        end
    end
    stats.num_grass = grass
    stats.num_weeds = weeds
    return nothing
end

# --- Termination ---

struct RGWTerminationSystem <: System end

function update!(::RGWTerminationSystem, world::World)
    tick = get_resource(world, Tick)
    params = get_resource(world, RGWParams)
    stats = get_resource(world, RGWStats)

    if stats.num_rabbits == 0 || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
