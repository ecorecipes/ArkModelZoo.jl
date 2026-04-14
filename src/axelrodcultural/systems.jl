# --- Initialization ---

struct InitAxelrodSystem <: System end

function initialize!(::InitAxelrodSystem, world::World)
    params = get_resource(world, AxelrodParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, AxelrodGrid)
    stats = get_resource(world, AxelrodStats)

    # Each patch gets random traits 0..q-1
    for x in 1:grid.width, y in 1:grid.height
        for f in 1:params.F
            grid.traits[f, x, y] = rand(rng, 0:params.q-1)
        end
    end

    # Count initial cultures
    _axelrod_count_cultures!(stats, grid, params)
    return nothing
end

function _axelrod_culture_id(grid::AxelrodGrid, x::Int, y::Int, q::Int)
    F = size(grid.traits, 1)
    id = 0
    for f in 1:F
        id = id * q + grid.traits[f, x, y]
    end
    return id
end

function _axelrod_count_cultures!(stats::AxelrodStats, grid::AxelrodGrid, params::AxelrodParams)
    cultures = Set{Int}()
    for x in 1:grid.width, y in 1:grid.height
        push!(cultures, _axelrod_culture_id(grid, x, y, params.q))
    end
    stats.number_of_cultures = length(cultures)
end

# --- Axelrod Update ---
# Each tick: ask patches in random order, each patch tries to interact with a Von Neumann neighbor.
# Non-wrapping grid.

struct AxelrodUpdateSystem <: System end

function update!(::AxelrodUpdateSystem, world::World)
    params = get_resource(world, AxelrodParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, AxelrodGrid)
    stats = get_resource(world, AxelrodStats)
    w, h = grid.width, grid.height
    F = params.F

    active_agents = 0

    # Random patch order (ask patches)
    patch_order = randperm(rng, w * h)

    for idx in patch_order
        x = mod1(idx, w)
        y = div(idx - 1, w) + 1

        # Get Von Neumann neighbors (non-wrapping)
        neighbors = Tuple{Int,Int}[]
        x > 1 && push!(neighbors, (x - 1, y))
        x < w && push!(neighbors, (x + 1, y))
        y > 1 && push!(neighbors, (x, y - 1))
        y < h && push!(neighbors, (x, y + 1))

        # Reservoir sample one active neighbor (0 < overlap < F)
        chosen_nx, chosen_ny = 0, 0
        chosen_overlap = 0
        count_active = 0

        for (nx, ny) in neighbors
            overlap = 0
            for f in 1:F
                if grid.traits[f, x, y] == grid.traits[f, nx, ny]
                    overlap += 1
                end
            end
            if overlap > 0 && overlap < F
                count_active += 1
                # Reservoir sampling: replace with probability 1/count_active
                if rand(rng, 1:count_active) == 1
                    chosen_nx, chosen_ny = nx, ny
                    chosen_overlap = overlap
                end
            end
        end

        if count_active > 0
            active_agents += 1
            # With probability overlap/F, adopt one differing trait
            if rand(rng) < chosen_overlap / F
                # Find differing traits
                differing = Int[]
                for f in 1:F
                    if grid.traits[f, x, y] != grid.traits[f, chosen_nx, chosen_ny]
                        push!(differing, f)
                    end
                end
                if !isempty(differing)
                    f_pick = differing[rand(rng, 1:length(differing))]
                    grid.traits[f_pick, x, y] = grid.traits[f_pick, chosen_nx, chosen_ny]
                end
            end
        end
    end

    stats.number_of_active_agents = active_agents
    return nothing
end

# --- Stats ---

struct AxelrodStatsSystem <: System end

function update!(::AxelrodStatsSystem, world::World)
    grid = get_resource(world, AxelrodGrid)
    params = get_resource(world, AxelrodParams)
    stats = get_resource(world, AxelrodStats)
    _axelrod_count_cultures!(stats, grid, params)
    return nothing
end

# --- Termination ---

struct AxelrodTerminationSystem <: System end

function update!(::AxelrodTerminationSystem, world::World)
    stats = get_resource(world, AxelrodStats)
    params = get_resource(world, AxelrodParams)
    tick = get_resource(world, Tick)
    if stats.number_of_active_agents == 0 || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
