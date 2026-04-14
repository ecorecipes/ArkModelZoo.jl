# --- Initialization ---

struct InitSegregationSystem <: System end

function initialize!(::InitSegregationSystem, world::World)
    params = get_resource(world, SegregationParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, SegregationGrid)

    # Density-based initialization: each patch has density% chance of an agent
    # Color is random per agent (one-of [red green]), matching NetLogo one-of [105 27]
    for x in 1:grid.width, y in 1:grid.height
        if rand(rng, 0:99) < round(Int, params.density)
            is_red = rand(rng, Bool)
            eid = new_entity!(world, (
                GridPosition(x, y),
                AgentColor(is_red),
                Happiness(),
            ))
            set_cell!(grid, x, y, eid)
        end
    end

    # Match NetLogo setup: compute initial happiness + stats (update-turtles; update-globals)
    update!(UpdateHappinessSystem(), world)
    return nothing
end

# --- Update Happiness ---

struct UpdateHappinessSystem <: System end

function update!(::UpdateHappinessSystem, world::World)
    params = get_resource(world, SegregationParams)
    grid = get_resource(world, SegregationGrid)
    stats = get_resource(world, SegregationStats)

    total_similar = 0
    total_neighbors = 0
    num_unhappy = 0
    num_happy = 0

    for (_, positions, colors, happinesses) in Query(world, (GridPosition, AgentColor, Happiness))
        @inbounds for i in eachindex(positions)
            pos = positions[i]
            color = colors[i]
            h = happinesses[i]

            similar = 0
            other = 0
            # Check Moore neighborhood (8 surrounding cells)
            for dx in -1:1, dy in -1:1
                (dx == 0 && dy == 0) && continue
                nx = pos.x + dx
                ny = pos.y + dy
                # Wrap around (toroidal)
                nx = mod1(nx, grid.width)
                ny = mod1(ny, grid.height)
                neighbor_eid = grid.cells[nx, ny]
                is_zero(neighbor_eid) && continue
                neighbor_color = get_components(world, neighbor_eid, (AgentColor,))[1]
                if neighbor_color.red == color.red
                    similar += 1
                else
                    other += 1
                end
            end

            total = similar + other
            h.similar_nearby = similar
            h.other_nearby = other
            h.total_nearby = total
            h.happy = total == 0 || (similar / total * 100.0 >= params.pct_similar_wanted)

            if h.happy
                num_happy += 1
            else
                num_unhappy += 1
            end
            total_similar += similar
            total_neighbors += total
        end
    end

    stats.num_happy = num_happy
    stats.num_unhappy = num_unhappy
    stats.percent_unhappy = (num_happy + num_unhappy) > 0 ?
        num_unhappy / (num_happy + num_unhappy) * 100.0 : 0.0
    stats.percent_similar = total_neighbors > 0 ?
        total_similar / total_neighbors * 100.0 : 0.0
    return nothing
end

# --- Move Unhappy Agents ---
# NetLogo: ask turtles with [not happy?] [find-new-spot]
# find-new-spot: rt random-float 360; fd random-float 10;
#                if any? other turtles-here [ find-new-spot ]; move-to patch-here
# Note: recursive — does random walk from current position until empty patch found

struct MoveUnhappySystem <: System end

function update!(::MoveUnhappySystem, world::World)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, SegregationGrid)

    # Collect unhappy agents
    unhappy = Tuple{Entity, Int, Int}[]
    for (eids, positions, _, happinesses) in Query(world, (GridPosition, AgentColor, Happiness))
        @inbounds for i in eachindex(positions)
            if !happinesses[i].happy
                push!(unhappy, (eids[i], positions[i].x, positions[i].y))
            end
        end
    end

    # NetLogo `ask` shuffles agentset each time
    Random.shuffle!(rng, unhappy)

    # Move each unhappy agent using random walk (matching NetLogo's recursive find-new-spot)
    # Clear old cell BEFORE walking so the turtle's spot is available (like NetLogo fd)
    for (eid, ox, oy) in unhappy
        clear_cell!(grid, ox, oy)
        nx, ny = _find_new_spot(rng, ox, oy, grid)
        set_cell!(grid, nx, ny, eid)
        pos = get_components(world, eid, (GridPosition,))[1]
        pos.x = nx
        pos.y = ny
    end
    return nothing
end

function _find_new_spot(rng, x::Int, y::Int, grid::SegregationGrid; max_tries::Int=500)
    w, h = grid.width, grid.height
    # Start from continuous position at patch center
    cx, cy = Float64(x), Float64(y)
    heading = 0.0
    for _ in 1:max_tries
        # NetLogo: rt random-float 360 (relative turn); fd random-float 10
        heading += rand(rng) * 360.0
        dist = rand(rng) * 10.0
        θ = deg2rad(heading)
        cx += sin(θ) * dist
        cy += cos(θ) * dist
        # Snap to nearest patch (toroidal)
        gx = mod1(round(Int, cx), w)
        gy = mod1(round(Int, cy), h)
        if is_zero(grid.cells[gx, gy])
            return gx, gy
        end
        # Continue walk from new continuous position (don't reset to patch center)
    end
    return x, y  # fallback: stay put
end

# --- Termination ---

struct SegregationTerminationSystem <: System end

function update!(::SegregationTerminationSystem, world::World)
    stats = get_resource(world, SegregationStats)
    params = get_resource(world, SegregationParams)
    tick = get_resource(world, Tick)

    if stats.num_unhappy == 0 || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
