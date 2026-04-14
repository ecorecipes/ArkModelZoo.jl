# --- Initialization ---

struct InitBBSystem <: System end

function initialize!(::InitBBSystem, world::World)
    params = get_resource(world, BBParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, BBGrid)
    w, h = grid.width, grid.height

    for x in 1:w, y in 1:h
        if rand(rng) < params.initial_density
            grid.state[x, y] = 1  # firing
        else
            grid.state[x, y] = 0  # dead
        end
    end

    _bb_update_stats!(world)
    return nothing
end

# --- Go ---

struct BBGoSystem <: System end

function update!(::BBGoSystem, world::World)
    grid = get_resource(world, BBGrid)
    w, h = grid.width, grid.height

    # Phase 1: count firing neighbors
    for x in 1:w, y in 1:h
        cnt = 0
        for dx in -1:1, dy in -1:1
            (dx == 0 && dy == 0) && continue
            nx = mod1(x + dx, w)
            ny = mod1(y + dy, h)
            if grid.state[nx, ny] == 1
                cnt += 1
            end
        end
        grid.firing_neighbors[x, y] = cnt
    end

    # Phase 2: update states
    for x in 1:w, y in 1:h
        s = grid.state[x, y]
        if s == 1
            # firing -> refractory
            grid.state[x, y] = 2
        elseif s == 2
            # refractory -> dead
            grid.state[x, y] = 0
        else
            # dead -> firing if exactly 2 firing neighbors
            if grid.firing_neighbors[x, y] == 2
                grid.state[x, y] = 1
            end
        end
    end

    _bb_update_stats!(world)
    return nothing
end

function _bb_update_stats!(world::World)
    grid = get_resource(world, BBGrid)
    stats = get_resource(world, BBStats)
    firing = 0; refractory = 0; dead = 0
    for x in 1:grid.width, y in 1:grid.height
        s = grid.state[x, y]
        if s == 1
            firing += 1
        elseif s == 2
            refractory += 1
        else
            dead += 1
        end
    end
    stats.firing_count = firing
    stats.refractory_count = refractory
    stats.dead_count = dead
end

# --- Termination ---

struct BBTerminationSystem <: System end

function update!(::BBTerminationSystem, world::World)
    params = get_resource(world, BBParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
