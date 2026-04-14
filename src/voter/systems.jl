# --- Initialization ---

struct InitVoterSystem <: System end

function initialize!(::InitVoterSystem, world::World)
    params = get_resource(world, VoterParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, VoterGrid)
    stats = get_resource(world, VoterStats)

    # Each patch gets random color 0 or 1 (representing two colors from pcolors)
    for x in 1:grid.width, y in 1:grid.height
        grid.colors[x, y] = rand(rng, 0:1)
    end

    # Count unique colors
    stats.n_colors = length(unique(grid.colors))
    return nothing
end

# --- Voter Update ---
# NetLogo: repeat N [ ask one-of patches [ set pcolor [pcolor] of one-of neighbors4 ] ]
# N individual random patch selections per tick; each copies a random Von Neumann neighbor's color.

struct VoterUpdateSystem <: System end

function update!(::VoterUpdateSystem, world::World)
    grid = get_resource(world, VoterGrid)
    rng = get_resource(world, RNGResource).rng
    w, h = grid.width, grid.height
    n = w * h

    for _ in 1:n
        # Pick a random patch
        x = rand(rng, 1:w)
        y = rand(rng, 1:h)

        # Pick a random Von Neumann neighbor (toroidal wrapping)
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

        grid.colors[x, y] = grid.colors[nx, ny]
    end
    return nothing
end

# --- Stats ---

struct VoterStatsSystem <: System end

function update!(::VoterStatsSystem, world::World)
    grid = get_resource(world, VoterGrid)
    stats = get_resource(world, VoterStats)
    stats.n_colors = length(unique(grid.colors))
    return nothing
end

# --- Termination ---

struct VoterTerminationSystem <: System end

function update!(::VoterTerminationSystem, world::World)
    stats = get_resource(world, VoterStats)
    params = get_resource(world, VoterParams)
    tick = get_resource(world, Tick)

    if stats.n_colors == 1 || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
