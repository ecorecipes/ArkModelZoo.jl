const INFLIFE_NEIGHBOR_OFFSETS = (
    (-1, 1), (0, 1), (1, 1),
    (-1, 0),         (1, 0),
    (-1, -1), (0, -1), (1, -1),
)

# --- Initialization ---

struct InitInfLifeSystem <: System end

function initialize!(::InitInfLifeSystem, world::World)
    params = get_resource(world, InfLifeParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, InfLifeGrid)
    stats = get_resource(world, InfLifeStats)

    empty!(grid.cells)
    for x in params.init_min:params.init_max
        for y in params.init_min:params.init_max
            if rand(rng) < params.init_density
                push!(grid.cells, (x, y))
            end
        end
    end
    stats.n_cells = length(grid.cells)
    return nothing
end

# --- Game of Life Step ---

struct InfLifeStepSystem <: System end

function update!(::InfLifeStepSystem, world::World)
    grid = get_resource(world, InfLifeGrid)
    stats = get_resource(world, InfLifeStats)
    cells = grid.cells

    # Count neighbors for all candidate cells
    neighbor_counts = Dict{Tuple{Int,Int}, Int}()
    for (cx, cy) in cells
        for (dx, dy) in INFLIFE_NEIGHBOR_OFFSETS
            pos = (cx + dx, cy + dy)
            neighbor_counts[pos] = get(neighbor_counts, pos, 0) + 1
        end
    end

    # Apply GoL rules
    next_cells = Set{Tuple{Int,Int}}()
    for (pos, count) in neighbor_counts
        alive = pos in cells
        if alive
            if count == 2 || count == 3
                push!(next_cells, pos)
            end
        else
            if count == 3
                push!(next_cells, pos)
            end
        end
    end
    # Also check live cells with 0 neighbors (they die, so no need to add)

    grid.cells = next_cells
    stats.n_cells = length(next_cells)
    return nothing
end

# --- Termination ---

struct InfLifeTerminationSystem <: System end

function update!(::InfLifeTerminationSystem, world::World)
    params = get_resource(world, InfLifeParams)
    tick = get_resource(world, Tick)
    stats = get_resource(world, InfLifeStats)
    if stats.n_cells == 0 || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
