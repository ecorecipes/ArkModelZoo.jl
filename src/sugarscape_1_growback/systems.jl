# --- Initialization ---

struct InitS1GSystem <: System end

function initialize!(::InitS1GSystem, world::World)
    params = get_resource(world, S1GParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, S1GGrid)
    w, h = grid.width, grid.height

    # Generate sugar landscape matching NetLogo: peaks at (35,35) and (15,15)
    # in 0-indexed coords, which is (36,36) and (16,16) in 1-indexed
    # NetLogo uses distancexy which respects wrapping
    cx1, cy1 = 16, 16   # NetLogo (15,15) in 0-indexed
    cx2, cy2 = 36, 36   # NetLogo (35,35) in 0-indexed
    for x in 1:w, y in 1:h
        # Wrapping distance (matching NetLogo distancexy)
        dx1 = min(abs(x - cx1), w - abs(x - cx1))
        dy1 = min(abs(y - cy1), h - abs(y - cy1))
        d1 = sqrt(Float64(dx1)^2 + Float64(dy1)^2)
        dx2 = min(abs(x - cx2), w - abs(x - cx2))
        dy2 = min(abs(y - cy2), h - abs(y - cy2))
        d2 = sqrt(Float64(dx2)^2 + Float64(dy2)^2)
        d = min(d1, d2)
        ms = 0.0
        if d <= 20; ms = 1.0; end
        if d <= 15; ms = 2.0; end
        if d <= 10; ms = 3.0; end
        if d <= 5;  ms = 4.0; end
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
        # Move: collect unoccupied vision patches + current patch (always included)
        # NetLogo: (patch-set patch-here (patches at-points vision-points) with [not any? turtles-here])
        # The `with` filter applies to vision patches only, NOT to patch-here
        # So patch-here is ALWAYS a candidate (distance=0 makes it win ties)
        candidates = Tuple{Int,Int}[]
        push!(candidates, (ag.x, ag.y))  # patch-here always included
        for (ddx, ddy) in ((0, 1), (0, -1), (1, 0), (-1, 0))
            for d in 1:ag.vision
                nx = mod1(ag.x + ddx * d, w)
                ny = mod1(ag.y + ddy * d, h)
                if is_zero(grid.occupant[nx, ny])
                    push!(candidates, (nx, ny))
                end
            end
        end
        unique!(candidates)

        # with-max [psugar]
        max_ps = maximum(grid.psugar[c[1], c[2]] for c in candidates)
        winners = filter(c -> grid.psugar[c[1], c[2]] == max_ps, candidates)

        # min-one-of [distance myself] (wrapping Euclidean distance)
        function wdist(cx, cy)
            dx = min(abs(cx - ag.x), w - abs(cx - ag.x))
            dy = min(abs(cy - ag.y), h - abs(cy - ag.y))
            return sqrt(Float64(dx)^2 + Float64(dy)^2)
        end
        min_d = minimum(wdist(c[1], c[2]) for c in winners)
        closest = filter(c -> wdist(c[1], c[2]) == min_d, winners)
        chosen = closest[rand(rng, 1:length(closest))]

        if chosen != (ag.x, ag.y)
            grid.occupant[ag.x, ag.y] = zero_entity
            ag.x, ag.y = chosen
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
