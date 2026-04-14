# --- Initialization ---
# NetLogo: ask patches [ ifelse random N < initial-pop [ black ] [ white ] ]
# random N returns integer in [0, N-1]

struct InitContactSystem <: System end

function initialize!(::InitContactSystem, world::World)
    params = get_resource(world, ContactProcessParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, ContactGrid)
    stats = get_resource(world, ContactStats)

    N = grid.width * grid.height
    for x in 1:grid.width, y in 1:grid.height
        grid.occupied[x, y] = rand(rng, 0:N-1) < params.initial_pop
    end

    stats.p_occupied = count(grid.occupied) / N
    return nothing
end

# --- Contact Process Update ---
# NetLogo: repeat N [ ask one-of patches [ ifelse pcolor = black [ death-event ] [ birth-event ] ] ]
# N individual random patch picks per tick. A patch can be picked multiple times.
# death-event: if random-float 1 < p-death → set pcolor white
# birth-event: set pcolor [pcolor] of one-of neighbors4

struct ContactUpdateSystem <: System end

function update!(::ContactUpdateSystem, world::World)
    params = get_resource(world, ContactProcessParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, ContactGrid)
    w, h = grid.width, grid.height
    N = w * h

    for _ in 1:N
        x = rand(rng, 1:w)
        y = rand(rng, 1:h)

        if grid.occupied[x, y]
            # death-event: random-float 1 < p-death → become empty
            if rand(rng) < params.p_death
                grid.occupied[x, y] = false
            end
        else
            # birth-event: copy state from random Von Neumann neighbor (toroidal)
            dir = rand(rng, 1:4)
            nx, ny = if dir == 1
                (mod1(x - 1, w), y)       # left
            elseif dir == 2
                (mod1(x + 1, w), y)       # right
            elseif dir == 3
                (x, mod1(y - 1, h))       # down
            else
                (x, mod1(y + 1, h))       # up
            end
            grid.occupied[x, y] = grid.occupied[nx, ny]
        end
    end
    return nothing
end

# --- Stats ---

struct ContactStatsSystem <: System end

function update!(::ContactStatsSystem, world::World)
    grid = get_resource(world, ContactGrid)
    stats = get_resource(world, ContactStats)
    N = grid.width * grid.height
    stats.p_occupied = count(grid.occupied) / N
    return nothing
end

# --- Termination ---
# Stop if no occupied patches or max_ticks reached

struct ContactTerminationSystem <: System end

function update!(::ContactTerminationSystem, world::World)
    grid = get_resource(world, ContactGrid)
    params = get_resource(world, ContactProcessParams)
    tick = get_resource(world, Tick)

    if !any(grid.occupied) || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
