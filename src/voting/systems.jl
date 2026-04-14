# --- Initialization ---

struct InitVOTSystem <: System end

function initialize!(::InitVOTSystem, world::World)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, VOTGrid)
    w, h = grid.width, grid.height

    for x in 1:w, y in 1:h
        grid.vote[x, y] = rand(rng, 0:1)
    end

    _vot_update_stats!(world)
    return nothing
end

# --- Go ---

struct VOTGoSystem <: System end

function update!(::VOTGoSystem, world::World)
    params = get_resource(world, VOTParams)
    grid = get_resource(world, VOTGrid)
    w, h = grid.width, grid.height

    # Phase 1: compute totals (sum of 8 neighbors' votes)
    for x in 1:w, y in 1:h
        s = 0
        for dx in -1:1, dy in -1:1
            (dx == 0 && dy == 0) && continue
            nx = mod1(x + dx, w)
            ny = mod1(y + dy, h)
            s += grid.vote[nx, ny]
        end
        grid.total[x, y] = s
    end

    # Phase 2: update votes based on totals
    for x in 1:w, y in 1:h
        t = grid.total[x, y]
        if t > 5
            grid.vote[x, y] = 1
        elseif t < 3
            grid.vote[x, y] = 0
        elseif t == 4
            if params.change_vote_if_tied
                grid.vote[x, y] = 1 - grid.vote[x, y]
            end
        elseif t == 5
            if params.award_close_calls_to_loser
                grid.vote[x, y] = 0
            else
                grid.vote[x, y] = 1
            end
        elseif t == 3
            if params.award_close_calls_to_loser
                grid.vote[x, y] = 1
            else
                grid.vote[x, y] = 0
            end
        end
    end

    _vot_update_stats!(world)
    return nothing
end

function _vot_update_stats!(world::World)
    grid = get_resource(world, VOTGrid)
    stats = get_resource(world, VOTStats)
    blue = 0
    green = 0
    for x in 1:grid.width, y in 1:grid.height
        if grid.vote[x, y] == 1
            blue += 1
        else
            green += 1
        end
    end
    stats.blue_count = blue
    stats.green_count = green
end

# --- Termination ---

struct VOTTerminationSystem <: System end

function update!(::VOTTerminationSystem, world::World)
    params = get_resource(world, VOTParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
