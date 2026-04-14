# --- Initialization ---

struct InitGBTSystem <: System end

function initialize!(::InitGBTSystem, world::World)
    params = get_resource(world, GBTParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, GBTGrid)
    stats = get_resource(world, GBTStats)

    # Each patch gets random type 0, 1, or 2
    for x in 1:grid.width, y in 1:grid.height
        grid.types[x, y] = rand(rng, 0:2)
    end

    stats.n_trees = count(==(2), grid.types)
    return nothing
end

# --- GBT Update ---
# NetLogo: repeat N [ ask one-of patches [ coin-flip death-event or birth-event ] ]
# Death: any type → grass with prob norm-d
# Birth: brush spreads to grass neighbor (prob norm-b-1), tree spreads to grass/brush neighbor (prob norm-b-2)

struct GBTUpdateSystem <: System end

function update!(::GBTUpdateSystem, world::World)
    grid = get_resource(world, GBTGrid)
    params = get_resource(world, GBTParams)
    rng = get_resource(world, RNGResource).rng
    w, h = grid.width, grid.height
    n = w * h

    max_rate = max(params.birth_rate_1, params.birth_rate_2)
    norm_d = 1.0 / max_rate
    norm_b_1 = params.birth_rate_1 / max_rate
    norm_b_2 = params.birth_rate_2 / max_rate

    for _ in 1:n
        # Pick a random patch
        x = rand(rng, 1:w)
        y = rand(rng, 1:h)

        if rand(rng, 0:1) == 1
            # Death event: any type → grass with prob norm_d
            if rand(rng) < norm_d
                grid.types[x, y] = 0
            end
        else
            # Birth event
            ptype = grid.types[x, y]
            if ptype == 1
                # Brush spreads to a grass neighbor
                if rand(rng) < norm_b_1
                    dir = rand(rng, 1:4)
                    nx, ny = if dir == 1
                        (mod1(x - 1, w), y)
                    elseif dir == 2
                        (mod1(x + 1, w), y)
                    elseif dir == 3
                        (x, mod1(y - 1, h))
                    else
                        (x, mod1(y + 1, h))
                    end
                    if grid.types[nx, ny] == 0
                        grid.types[nx, ny] = 1
                    end
                end
            elseif ptype == 2
                # Tree spreads to a grass or brush neighbor
                if rand(rng) < norm_b_2
                    dir = rand(rng, 1:4)
                    nx, ny = if dir == 1
                        (mod1(x - 1, w), y)
                    elseif dir == 2
                        (mod1(x + 1, w), y)
                    elseif dir == 3
                        (x, mod1(y - 1, h))
                    else
                        (x, mod1(y + 1, h))
                    end
                    if grid.types[nx, ny] < 2
                        grid.types[nx, ny] = 2
                    end
                end
            end
        end
    end
    return nothing
end

# --- Stats ---

struct GBTStatsSystem <: System end

function update!(::GBTStatsSystem, world::World)
    grid = get_resource(world, GBTGrid)
    stats = get_resource(world, GBTStats)
    stats.n_trees = count(==(2), grid.types)
    return nothing
end

# --- Termination ---

struct GBTTerminationSystem <: System end

function update!(::GBTTerminationSystem, world::World)
    params = get_resource(world, GBTParams)
    tick = get_resource(world, Tick)

    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
