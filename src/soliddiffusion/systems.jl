# --- Initialization ---

struct InitSDSystem <: System end

function initialize!(::InitSDSystem, world::World)
    params = get_resource(world, SolidDiffusionParams)
    grid = get_resource(world, SDGrid)
    stats = get_resource(world, SDStats)
    w, h = grid.width, grid.height
    cx = (w + 1) ÷ 2  # center x = 18 for 35-wide grid

    n = 0
    for x in 1:w, y in 1:h
        pxcor = x - cx
        if pxcor < 0
            grid.cells[x, y] = 1  # green
            n += 1
        elseif pxcor > 0
            grid.cells[x, y] = 2  # blue
            n += 1
        else
            grid.cells[x, y] = 0  # empty (center column)
        end
    end
    stats.n_turtles = n
    return nothing
end

# --- Update ---

struct SDUpdateSystem <: System end

function update!(::SDUpdateSystem, world::World)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, SDGrid)
    stats = get_resource(world, SDStats)
    w, h = grid.width, grid.height
    cells = grid.cells

    # Iterate empty patches in random order
    perm = randperm(rng, w * h)
    for idx in perm
        y = (idx - 1) ÷ w + 1
        x = (idx - 1) % w + 1
        cells[x, y] != 0 && continue  # skip non-empty

        # Check Von Neumann neighbors (no wrapping)
        neighbors = Tuple{Int,Int}[]
        if x > 1 && cells[x-1, y] != 0
            push!(neighbors, (x-1, y))
        end
        if x < w && cells[x+1, y] != 0
            push!(neighbors, (x+1, y))
        end
        if y > 1 && cells[x, y-1] != 0
            push!(neighbors, (x, y-1))
        end
        if y < h && cells[x, y+1] != 0
            push!(neighbors, (x, y+1))
        end

        if !isempty(neighbors)
            # Pick random occupied neighbor
            nx, ny = neighbors[rand(rng, 1:length(neighbors))]
            # Move atom to empty patch
            cells[x, y] = cells[nx, ny]
            cells[nx, ny] = 0
        end
    end

    # Count turtles
    n = 0
    for i in eachindex(cells)
        if cells[i] != 0
            n += 1
        end
    end
    stats.n_turtles = n

    return nothing
end

# --- Termination ---

struct SDTerminationSystem <: System end

function update!(::SDTerminationSystem, world::World)
    params = get_resource(world, SolidDiffusionParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
