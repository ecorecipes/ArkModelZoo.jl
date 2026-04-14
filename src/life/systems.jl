const LF_NEIGHBOR_OFFSETS = (
    (-1, -1), (0, -1), (1, -1),
    (-1,  0),          (1,  0),
    (-1,  1), (0,  1), (1,  1),
)

# --- Initialization ---

struct InitLFSystem <: System end

function initialize!(::InitLFSystem, world::World)
    params = get_resource(world, LFParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, LFGrid)
    stats = get_resource(world, LFStats)

    # NetLogo: ifelse random-float 100 < initial-density [cell-birth] [cell-death]
    for x in 1:grid.width, y in 1:grid.height
        grid.cells[x, y] = rand(rng) * 100.0 < params.initial_density
    end

    _lf_update_stats!(grid, stats)
    return nothing
end

# --- Game of Life Step ---

struct LFGoSystem <: System end

function update!(::LFGoSystem, world::World)
    grid = get_resource(world, LFGrid)
    stats = get_resource(world, LFStats)
    w, h = grid.width, grid.height
    cells = grid.cells
    neighbors = grid.neighbors

    # Phase 1: count live neighbors (toroidal Moore neighborhood)
    @inbounds for x in 1:w, y in 1:h
        count = 0
        for (dx, dy) in LF_NEIGHBOR_OFFSETS
            nx = mod1(x + dx, w)
            ny = mod1(y + dy, h)
            count += cells[nx, ny]
        end
        neighbors[x, y] = count
    end

    # Phase 2: apply rules synchronously
    # if neighbors == 3 → alive; if neighbors != 2 → dead; else unchanged
    @inbounds for x in 1:w, y in 1:h
        n = neighbors[x, y]
        if n == 3
            cells[x, y] = true
        elseif n != 2
            cells[x, y] = false
        end
    end

    _lf_update_stats!(grid, stats)
    return nothing
end

# --- Termination ---

struct LFTerminationSystem <: System end

function update!(::LFTerminationSystem, world::World)
    params = get_resource(world, LFParams)
    tick = get_resource(world, Tick)
    stats = get_resource(world, LFStats)
    if stats.living_count == 0 || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end

# --- Helper ---

function _lf_update_stats!(grid::LFGrid, stats::LFStats)
    n = count(grid.cells)
    stats.living_count = n
    stats.density = n / (grid.width * grid.height) * 100.0
    return nothing
end
