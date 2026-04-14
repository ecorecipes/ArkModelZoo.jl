# --- Initialization ---
# NetLogo: ask n-of (p * count patches) patches [set pcolor green]

struct InitFirePercSystem <: System end

function initialize!(::InitFirePercSystem, world::World)
    params = get_resource(world, FirePercolationParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, FirePercGrid)
    stats = get_resource(world, FirePercStats)

    N = grid.width * grid.height
    n_green = floor(Int, params.p * N)

    perm = randperm(rng, N)
    for i in 1:n_green
        idx = perm[i]
        x = mod1(idx, grid.width)
        y = div(idx - 1, grid.width) + 1
        grid.state[x, y] = 1  # green
    end

    stats.fire_size = 0
    return nothing
end

# --- Fire Spread ---
# Tick 0: ignite one random green patch, then spread.
# Tick 1+: spread from current fire front to green Von Neumann neighbors (toroidal).

struct FirePercSpreadSystem <: System end

function update!(::FirePercSpreadSystem, world::World)
    grid = get_resource(world, FirePercGrid)
    tick = get_resource(world, Tick)
    rng = get_resource(world, RNGResource).rng
    w, h = grid.width, grid.height

    if tick.tick == 0
        # Ignite one random green patch
        green_patches = Tuple{Int,Int}[]
        for x in 1:w, y in 1:h
            if grid.state[x, y] == 1
                push!(green_patches, (x, y))
            end
        end
        if isempty(green_patches)
            return nothing
        end
        ix, iy = green_patches[rand(rng, 1:length(green_patches))]
        grid.state[ix, iy] = 2  # red
        push!(grid.fire_front, (ix, iy))
    end

    # Spread fire from current front
    new_front = Set{Tuple{Int,Int}}()
    for (x, y) in grid.fire_front
        for (nx, ny) in ((mod1(x - 1, w), y),
                         (mod1(x + 1, w), y),
                         (x, mod1(y - 1, h)),
                         (x, mod1(y + 1, h)))
            if grid.state[nx, ny] == 1
                push!(new_front, (nx, ny))
            end
        end
    end

    for (x, y) in new_front
        grid.state[x, y] = 2  # red
    end

    grid.fire_front = new_front
    return nothing
end

# --- Stats ---

struct FirePercStatsSystem <: System end

function update!(::FirePercStatsSystem, world::World)
    grid = get_resource(world, FirePercGrid)
    stats = get_resource(world, FirePercStats)
    stats.fire_size = count(==(2), grid.state)
    return nothing
end

# --- Termination ---
# Stop when fire front is empty or max_ticks reached.

struct FirePercTerminationSystem <: System end

function update!(::FirePercTerminationSystem, world::World)
    grid = get_resource(world, FirePercGrid)
    params = get_resource(world, FirePercolationParams)
    tick = get_resource(world, Tick)

    if isempty(grid.fire_front) || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
