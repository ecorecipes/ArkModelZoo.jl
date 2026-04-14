# --- Initialization ---

struct InitS1GSystem <: System end

function initialize!(::InitS1GSystem, world::World)
    params = get_resource(world, S1GParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, S1GGrid)
    w, h = grid.width, grid.height

    # Generate sugar landscape: two peaks like the classic Sugarscape
    # Peak 1 at (w/4, h/4), Peak 2 at (3w/4, 3h/4), max sugar = 4
    cx1, cy1 = w ÷ 4, h ÷ 4
    cx2, cy2 = 3w ÷ 4, 3h ÷ 4
    for x in 1:w, y in 1:h
        d1 = sqrt((x - cx1)^2 + (y - cy1)^2)
        d2 = sqrt((x - cx2)^2 + (y - cy2)^2)
        d = min(d1, d2)
        if d <= 5
            ms = 4.0
        elseif d <= 10
            ms = 3.0
        elseif d <= 15
            ms = 2.0
        elseif d <= 20
            ms = 1.0
        else
            ms = 0.0
        end
        grid.max_psugar[x, y] = ms
        grid.psugar[x, y] = ms
    end

    # Place agents on random unoccupied patches
    all_positions = [(x, y) for x in 1:w for y in 1:h]
    Random.shuffle!(rng, all_positions)
    placed = 0
    for (x, y) in all_positions
        placed >= params.initial_population && break
        agent = S1GAgent()
        agent.x = x
        agent.y = y
        agent.sugar = Float64(5 + rand(rng, 0:20))   # random-in-range 5 25
        agent.metabolism = 1 + rand(rng, 0:3)          # random-in-range 1 4
        agent.vision = 1 + rand(rng, 0:5)             # random-in-range 1 6
        eid = new_entity!(world, (agent,))
        grid.occupant[x, y] = eid
        placed += 1
    end

    _s1g_update_stats!(world)
    return nothing
end

# --- Go ---

struct S1GGoSystem <: System end

function update!(::S1GGoSystem, world::World)
    params = get_resource(world, S1GParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, S1GGrid)
    w, h = grid.width, grid.height

    # Immediate growback
    for x in 1:w, y in 1:h
        grid.psugar[x, y] = grid.max_psugar[x, y]
    end

    # Collect agents
    agents = Tuple{Entity, S1GAgent}[]
    for (eids, agent_arr) in Query(world, (S1GAgent,))
        for i in eachindex(eids)
            push!(agents, (eids[i], agent_arr[i]))
        end
    end
    Random.shuffle!(rng, agents)

    dead = Entity[]
    for (eid, ag) in agents
        # Move: look in 4 cardinal directions up to vision distance
        # Pick unoccupied patch with most sugar, closest if tie
        best_x, best_y = ag.x, ag.y
        best_sugar = grid.psugar[ag.x, ag.y]
        best_dist = 0

        for (ddx, ddy) in ((0, 1), (0, -1), (1, 0), (-1, 0))
            for d in 1:ag.vision
                nx = mod1(ag.x + ddx * d, w)
                ny = mod1(ag.y + ddy * d, h)
                if is_zero(grid.occupant[nx, ny]) || (nx == ag.x && ny == ag.y)
                    ps = grid.psugar[nx, ny]
                    if ps > best_sugar || (ps == best_sugar && d < best_dist)
                        best_sugar = ps
                        best_x = nx
                        best_y = ny
                        best_dist = d
                    end
                end
            end
        end

        # Move to best location
        if best_x != ag.x || best_y != ag.y
            grid.occupant[ag.x, ag.y] = zero_entity
            ag.x = best_x
            ag.y = best_y
            grid.occupant[ag.x, ag.y] = eid
        end

        # Eat
        ag.sugar = ag.sugar - ag.metabolism + grid.psugar[ag.x, ag.y]
        grid.psugar[ag.x, ag.y] = 0.0

        if ag.sugar <= 0
            push!(dead, eid)
            grid.occupant[ag.x, ag.y] = zero_entity
        end
    end

    # Remove dead agents
    for eid in dead
        remove_entity!(world, eid)
    end

    _s1g_update_stats!(world)
    return nothing
end

function _s1g_update_stats!(world::World)
    stats = get_resource(world, S1GStats)
    sugars = Float64[]
    for (_, agent_arr) in Query(world, (S1GAgent,))
        for ag in agent_arr
            push!(sugars, ag.sugar)
        end
    end
    n = length(sugars)
    stats.population = n
    if n > 0
        stats.mean_sugar = mean(sugars)
        stats.max_sugar = maximum(sugars)
        stats.min_sugar = minimum(sugars)
    else
        stats.mean_sugar = 0.0
        stats.max_sugar = 0.0
        stats.min_sugar = 0.0
    end
end

# --- Termination ---

struct S1GTerminationSystem <: System end

function update!(::S1GTerminationSystem, world::World)
    params = get_resource(world, S1GParams)
    tick = get_resource(world, Tick)
    stats = get_resource(world, S1GStats)
    if stats.population == 0 || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
