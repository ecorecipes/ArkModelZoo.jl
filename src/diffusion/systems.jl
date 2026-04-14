# --- Initialization ---

struct InitDiffusionSystem <: System end

function initialize!(::InitDiffusionSystem, world::World)
    grid = get_resource(world, DiffusionGrid)
    stats = get_resource(world, DiffusionStats)

    # Center patch (0,0) in NetLogo maps to (cx, cy) in a 33×33 grid
    cx = (grid.width ÷ 2) + 1
    cy = (grid.height ÷ 2) + 1

    # NetLogo: ask patch 0 0 [ set temp 100 ]
    grid.temp[cx, cy] = 100.0

    # NetLogo: ask neighbors [ set temp 50 ] — 8 Moore neighbors (toroidal)
    for (dx, dy) in ((-1,-1), (-1,0), (-1,1), (0,-1), (0,1), (1,-1), (1,0), (1,1))
        nx = mod1(cx + dx, grid.width)
        ny = mod1(cy + dy, grid.height)
        grid.temp[nx, ny] = 50.0
    end

    stats.max_temp = maximum(grid.temp)
    stats.mean_temp = Statistics.mean(grid.temp)
    return nothing
end

# --- Diffuse + Decay + Re-heat center ---
# NetLogo: diffuse temp 0.5
#   new[p] = old[p] * (1 - 0.5) + (0.5 / 8) * sum_of_8_neighbors(old)
#          = 0.5 * old[p] + 0.0625 * sum_neighbors(old)
# Then: set temp temp * 0.99  (decay)
# Then: ask patch 0 0 [ set temp 100 ]

struct DiffusionUpdateSystem <: System end

function update!(::DiffusionUpdateSystem, world::World)
    grid = get_resource(world, DiffusionGrid)
    w, h = grid.width, grid.height
    old = copy(grid.temp)

    # Diffuse temp 0.5
    for x in 1:w, y in 1:h
        s = 0.0
        for (dx, dy) in ((-1,-1), (-1,0), (-1,1), (0,-1), (0,1), (1,-1), (1,0), (1,1))
            nx = mod1(x + dx, w)
            ny = mod1(y + dy, h)
            s += old[nx, ny]
        end
        grid.temp[x, y] = 0.5 * old[x, y] + 0.0625 * s
    end

    # Decay: temp * 0.99
    for x in 1:w, y in 1:h
        grid.temp[x, y] *= 0.99
    end

    # Re-heat center
    cx = (w ÷ 2) + 1
    cy = (h ÷ 2) + 1
    grid.temp[cx, cy] = 100.0

    return nothing
end

# --- Stats ---

struct DiffusionStatsSystem <: System end

function update!(::DiffusionStatsSystem, world::World)
    grid = get_resource(world, DiffusionGrid)
    stats = get_resource(world, DiffusionStats)
    stats.max_temp = maximum(grid.temp)
    stats.mean_temp = Statistics.mean(grid.temp)
    return nothing
end

# --- Termination ---

struct DiffusionTerminationSystem <: System end

function update!(::DiffusionTerminationSystem, world::World)
    params = get_resource(world, DiffusionParams)
    tick = get_resource(world, Tick)

    # tick.tick is the count before this step's increment; after the step
    # it becomes tick.tick + 1.  Stop so that exactly max_ticks updates run.
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
