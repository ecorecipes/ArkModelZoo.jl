# --- Initialization ---

struct InitWDSystem <: System end

function initialize!(::InitWDSystem, world::World)
    params = get_resource(world, WDParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, WDGrid)
    w, h = grid.width, grid.height

    # setup-patches: assign best land, diffuse grain
    for x in 1:w, y in 1:h
        grid.max_grain_here[x, y] = 0.0
        if rand(rng) * 100.0 <= params.percent_best_land
            grid.max_grain_here[x, y] = Float64(params.max_grain)
            grid.grain_here[x, y] = Float64(params.max_grain)
        end
    end

    # repeat 5 [ ask patches with [max-grain-here != 0] [set grain-here max-grain-here]; diffuse grain-here 0.25 ]
    for _ in 1:5
        for x in 1:w, y in 1:h
            if grid.max_grain_here[x, y] != 0.0
                grid.grain_here[x, y] = grid.max_grain_here[x, y]
            end
        end
        diffuse!(grid.grain_here, 0.25, w, h)
    end

    # repeat 10 [ diffuse grain-here 0.25 ]
    for _ in 1:10
        diffuse!(grid.grain_here, 0.25, w, h)
    end

    # ask patches [ set grain-here floor grain-here; set max-grain-here grain-here ]
    for x in 1:w, y in 1:h
        grid.grain_here[x, y] = floor(grid.grain_here[x, y])
        grid.max_grain_here[x, y] = grid.grain_here[x, y]
    end

    # setup-turtles
    for _ in 1:params.num_people
        px = rand(rng, 1:w)
        py = rand(rng, 1:h)
        heading = rand(rng, [0, 90, 180, 270])
        le = params.life_expectancy_min + rand(rng, 0:(params.life_expectancy_max - params.life_expectancy_min))
        met = 1 + rand(rng, 0:params.metabolism_max - 1)
        wealth = met + rand(rng, 0:49)
        vis = 1 + rand(rng, 0:params.max_vision - 1)
        age = rand(rng, 0:le - 1)
        new_entity!(world, (
            WDPosition(px, py),
            WDHeading(heading),
            WDTurtle(age, wealth, le, met, vis),
            WDTag(),
        ))
    end

    # Initial Gini
    update!(WDGiniSystem(), world)
    return nothing
end

# --- Turn Towards Grain ---
# Each turtle looks N/E/S/W along its vision and picks the direction with most total grain

struct WDTurnSystem <: System end

function update!(::WDTurnSystem, world::World)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, WDGrid)
    w, h = grid.width, grid.height

    for (eids, positions, headings, turtles) in Query(world, (WDPosition, WDHeading, WDTurtle); with=(WDTag,))
        indices = collect(eachindex(positions))
        Random.shuffle!(rng, indices)
        @inbounds for i in indices
            pos = positions[i]
            vis = turtles[i].vision
            best_dir = 0
            best_amount = _wd_grain_ahead(grid, pos.x, pos.y, 0, vis, w, h)
            for dir in (90, 180, 270)
                amt = _wd_grain_ahead(grid, pos.x, pos.y, dir, vis, w, h)
                if amt > best_amount
                    best_dir = dir
                    best_amount = amt
                end
            end
            headings[i].heading = best_dir
        end
    end
    return nothing
end

function _wd_grain_ahead(grid::WDGrid, x::Int, y::Int, heading::Int, vision::Int, w::Int, h::Int)
    total = 0.0
    dx, dy = _wd_heading_delta(heading)
    cx, cy = x, y
    for _ in 1:vision
        cx = mod1(cx + dx, w)
        cy = mod1(cy + dy, h)
        total += grid.grain_here[cx, cy]
    end
    return total
end

function _wd_heading_delta(heading::Int)
    if heading == 0
        return (0, 1)   # North: y+1
    elseif heading == 90
        return (1, 0)   # East: x+1
    elseif heading == 180
        return (0, -1)  # South: y-1
    else  # 270
        return (-1, 0)  # West: x-1
    end
end

# --- Harvest ---
# First pass: all turtles gain floor(grain / num_turtles_here)
# Second pass: all turtles zero the grain on their patch

struct WDHarvestSystem <: System end

function update!(::WDHarvestSystem, world::World)
    grid = get_resource(world, WDGrid)

    # Build count of turtles per cell
    w, h = grid.width, grid.height
    counts = zeros(Int, w, h)
    for (_, positions) in Query(world, (WDPosition,); with=(WDTag,))
        @inbounds for i in eachindex(positions)
            counts[positions[i].x, positions[i].y] += 1
        end
    end

    # First pass: distribute grain
    for (_, positions, _, turtles) in Query(world, (WDPosition, WDHeading, WDTurtle); with=(WDTag,))
        @inbounds for i in eachindex(positions)
            px, py = positions[i].x, positions[i].y
            c = counts[px, py]
            if c > 0
                turtles[i].wealth = floor(Int, turtles[i].wealth + grid.grain_here[px, py] / c)
            end
        end
    end

    # Second pass: zero grain
    for (_, positions) in Query(world, (WDPosition,); with=(WDTag,))
        @inbounds for i in eachindex(positions)
            grid.grain_here[positions[i].x, positions[i].y] = 0.0
        end
    end
    return nothing
end

# --- Move, Eat, Age, Die ---
# fd 1 in heading direction, subtract metabolism, increment age, if dead: reset

struct WDMoveEatAgeDieSystem <: System end

function update!(::WDMoveEatAgeDieSystem, world::World)
    params = get_resource(world, WDParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, WDGrid)
    w, h = grid.width, grid.height

    for (eids, positions, headings, turtles) in Query(world, (WDPosition, WDHeading, WDTurtle); with=(WDTag,))
        indices = collect(eachindex(positions))
        Random.shuffle!(rng, indices)
        @inbounds for i in indices
            # fd 1
            dx, dy = _wd_heading_delta(headings[i].heading)
            positions[i].x = mod1(positions[i].x + dx, w)
            positions[i].y = mod1(positions[i].y + dy, h)

            # Consume metabolism
            turtles[i].wealth -= turtles[i].metabolism
            turtles[i].age += 1

            # Death check: reset turtle stats (constant population)
            # NetLogo: set-initial-turtle-vars — does NOT relocate, turtle stays
            if turtles[i].wealth < 0 || turtles[i].age >= turtles[i].life_expectancy
                headings[i].heading = rand(rng, [0, 90, 180, 270])
                turtles[i].life_expectancy = params.life_expectancy_min + rand(rng, 0:(params.life_expectancy_max - params.life_expectancy_min))
                turtles[i].metabolism = 1 + rand(rng, 0:params.metabolism_max - 1)
                turtles[i].wealth = turtles[i].metabolism + rand(rng, 0:49)
                turtles[i].vision = 1 + rand(rng, 0:params.max_vision - 1)
                turtles[i].age = rand(rng, 0:turtles[i].life_expectancy - 1)
            end
        end
    end
    return nothing
end

# --- Grow Grain ---

struct WDGrowGrainSystem <: System end

function update!(::WDGrowGrainSystem, world::World)
    params = get_resource(world, WDParams)
    tick = get_resource(world, Tick)
    grid = get_resource(world, WDGrid)

    # NetLogo: if ticks mod grain-growth-interval = 0
    if tick.tick % params.grain_growth_interval == 0
        for x in 1:grid.width, y in 1:grid.height
            if grid.grain_here[x, y] < grid.max_grain_here[x, y]
                grid.grain_here[x, y] = min(
                    grid.grain_here[x, y] + params.num_grain_grown,
                    grid.max_grain_here[x, y]
                )
            end
        end
    end
    return nothing
end

# --- Gini Computation ---

struct WDGiniSystem <: System end

function update!(::WDGiniSystem, world::World)
    params = get_resource(world, WDParams)
    stats = get_resource(world, WDStats)

    # Collect all wealths
    wealths = Int[]
    for (_, _, _, turtles) in Query(world, (WDPosition, WDHeading, WDTurtle); with=(WDTag,))
        @inbounds for i in eachindex(turtles)
            push!(wealths, turtles[i].wealth)
        end
    end

    sort!(wealths)
    n = length(wealths)
    total_wealth = sum(wealths)

    gini = 0.0
    wealth_sum_so_far = 0.0
    for idx in 1:n
        wealth_sum_so_far += wealths[idx]
        gini += (idx / n) - (wealth_sum_so_far / total_wealth)
    end

    stats.gini_index_reserve = gini
    return nothing
end

# --- Termination ---

struct WDTerminationSystem <: System end

function update!(::WDTerminationSystem, world::World)
    params = get_resource(world, WDParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
