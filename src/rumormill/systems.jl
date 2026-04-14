# --- Neighbor offsets ---

const RM_NEIGHBORS4 = ((0, 1), (0, -1), (1, 0), (-1, 0))
const RM_NEIGHBORS8 = (
    (-1, -1), (-1, 0), (-1, 1),
    (0, -1),           (0, 1),
    (1, -1),  (1, 0),  (1, 1),
)

# --- hear-rumor patch procedure ---

@inline function rm_hear_rumor!(grid::RMGrid, x::Int, y::Int, when::Int)
    if grid.first_heard[x, y] == -1
        grid.first_heard[x, y] = when
        grid.just_heard[x, y] = true
    end
    grid.times_heard[x, y] += 1
    return nothing
end

# --- update procedure: process just_heard patches, count clique ---

function rm_update!(grid::RMGrid, stats::RMStats, tick::Int)
    w, h = grid.width, grid.height
    for x in 1:w, y in 1:h
        if grid.just_heard[x, y]
            grid.just_heard[x, y] = false
            rm_hear_rumor!(grid, x, y, tick)
        end
    end
    stats.previous_clique = stats.clique
    n = 0
    for i in eachindex(grid.times_heard)
        if grid.times_heard[i] > 0
            n += 1
        end
    end
    stats.clique = n
    return nothing
end

# --- Initialization ---

struct InitRMSystem <: System end

function initialize!(::InitRMSystem, world::World)
    params = get_resource(world, RMParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, RMGrid)
    stats = get_resource(world, RMStats)

    if params.seed_one
        # Seed center patch: patch 0 0 → (ceil(w/2), ceil(h/2))
        cx = ceil(Int, grid.width / 2)
        cy = ceil(Int, grid.height / 2)
        rm_hear_rumor!(grid, cx, cy, 0)
    else
        # Seed random: each unheard patch hears if rand*100 < init_clique
        for x in 1:grid.width, y in 1:grid.height
            if grid.times_heard[x, y] == 0
                if rand(rng) * 100.0 < params.init_clique
                    rm_hear_rumor!(grid, x, y, 0)
                end
            end
        end
    end

    # Run initial update to process just_heard and count clique
    rm_update!(grid, stats, 0)
    return nothing
end

# --- Go step ---

struct RMGoSystem <: System end

function update!(::RMGoSystem, world::World)
    params = get_resource(world, RMParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, RMGrid)
    stats = get_resource(world, RMStats)
    tick = get_resource(world, Tick)
    w, h = grid.width, grid.height

    # Stop if all patches have heard the rumor
    all_heard = true
    for i in eachindex(grid.times_heard)
        if grid.times_heard[i] == 0
            all_heard = false
            break
        end
    end
    if all_heard
        get_resource(world, Terminate).stop = true
        return nothing
    end

    # Collect patches with times_heard > 0 and shuffle (NetLogo ask patches)
    heard_patches = Tuple{Int,Int}[]
    for x in 1:w, y in 1:h
        if grid.times_heard[x, y] > 0
            push!(heard_patches, (x, y))
        end
    end
    # Fisher-Yates shuffle
    n = length(heard_patches)
    for i in n:-1:2
        j = rand(rng, 1:i)
        heard_patches[i], heard_patches[j] = heard_patches[j], heard_patches[i]
    end

    neighbors = params.eight_mode ? RM_NEIGHBORS8 : RM_NEIGHBORS4

    # spread-rumor: each heard patch picks one random neighbor
    for (x, y) in heard_patches
        idx = rand(rng, 1:length(neighbors))
        dx, dy = neighbors[idx]
        nx = mod1(x + dx, w)
        ny = mod1(y + dy, h)
        grid.just_heard[nx, ny] = true
    end

    # Update: process just_heard, count clique
    # tick.tick is 0-based; NetLogo ticks is the current tick value after tick
    rm_update!(grid, stats, tick.tick + 1)
    return nothing
end

# --- Termination ---

struct RMTerminationSystem <: System end

function update!(::RMTerminationSystem, world::World)
    params = get_resource(world, RMParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
