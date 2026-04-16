# --- Initialization ---

struct InitBoilingSystem <: System end

function initialize!(::InitBoilingSystem, world::World)
    params = get_resource(world, BoilingParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, BoilingGrid)
    stats = get_resource(world, BoilingStats)

    # NetLogo: set heat random 212 → integer in [0, 211]
    for x in 1:grid.width, y in 1:grid.height
        grid.heat[x, y] = Float64(rand(rng, 0:211))
    end

    stats.avg_heat = Statistics.mean(grid.heat)
    return nothing
end

# --- Diffuse + Phase Transition ---
# NetLogo: diffuse heat 1 → new[p] = (1/8) * sum of 8 Moore neighbors (toroidal)
# Then: set heat (heat + 5) mod 212

struct BoilingUpdateSystem <: System end

function update!(::BoilingUpdateSystem, world::World)
    grid = get_resource(world, BoilingGrid)
    w, h = grid.width, grid.height

    # Full diffusion: diffuse heat 1
    diffuse!(grid.heat, 1.0, w, h)

    # Phase transition: (heat + 5) mod 212
    for x in 1:w, y in 1:h
        grid.heat[x, y] = mod(grid.heat[x, y] + 5.0, 212.0)
    end

    return nothing
end

# --- Stats ---

struct BoilingStatsSystem <: System end

function update!(::BoilingStatsSystem, world::World)
    grid = get_resource(world, BoilingGrid)
    stats = get_resource(world, BoilingStats)
    stats.avg_heat = Statistics.mean(grid.heat)
    return nothing
end

# --- Termination ---

struct BoilingTerminationSystem <: System end

function update!(::BoilingTerminationSystem, world::World)
    params = get_resource(world, BoilingParams)
    tick = get_resource(world, Tick)

    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
