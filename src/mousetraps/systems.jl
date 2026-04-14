# Mousetraps chain-reaction model systems
# Execution order: init → process balls → count stats → terminate

# --- Helper: random movement matching NetLogo non-wrapping forward ---
# NetLogo's `fd d` takes incremental steps of at most 1 unit each.
# At each step, if the destination is outside the world (Box topology:
# x >= max_pxcor+0.5 or x < min_pxcor-0.5), that step is abandoned
# and the turtle keeps the position from the last successful step.
# See _fdinternal.scala and Box.scala in the NetLogo source.

function _mousetraps_move(x::Float64, y::Float64, rng, max_dist::Float64, half_w::Int)
    θ = rand(rng) * 2π
    d = rand(rng) * max_dist
    dx = cos(θ)
    dy = sin(θ)
    bound = Float64(half_w) + 0.5
    remaining = d
    while remaining > 3.2e-15   # NetLogo Numbers.Infinitesimal
        step = min(1.0, remaining)
        new_x = x + dx * step
        new_y = y + dy * step
        if new_x >= bound || new_x < -bound || new_y >= bound || new_y < -bound
            break
        end
        x = new_x
        y = new_y
        remaining -= step
    end
    return x, y
end

# --- Initialization ---
# NetLogo: crt 1 at center (0,0)

struct InitMousetrapSystem <: System end

function initialize!(::InitMousetrapSystem, world::World)
    stats = get_resource(world, MousetrapStats)
    new_entity!(world, (BallPosition(0.0, 0.0),))
    stats.traps_triggered = 0
    stats.balls_in_air = 1
    return nothing
end

# --- Main system: process balls on patches ---
# NetLogo ask turtles: shuffled, sequential, grid updates visible within tick.
# Newly hatched turtles are NOT processed in the same tick.

struct MousetrapSystem <: System
    order::Vector{Int}
    to_spawn::Vector{Tuple{Float64,Float64}}
    to_kill::Vector{Entity}
end
MousetrapSystem() = MousetrapSystem(Int[], Tuple{Float64,Float64}[], Entity[])

function update!(system::MousetrapSystem, world::World)
    params = get_resource(world, MousetrapParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, MousetrapGrid)
    stats = get_resource(world, MousetrapStats)
    hw = params.half_width
    dim = 2 * hw + 1

    empty!(system.to_spawn)
    empty!(system.to_kill)

    # Collect all current balls into flat arrays
    n = 0
    for (eids, _) in Query(world, (BallPosition,))
        n += length(eids)
    end
    n == 0 && return nothing

    entities = Vector{Entity}(undef, n)
    xs = Vector{Float64}(undef, n)
    ys = Vector{Float64}(undef, n)
    idx = 0
    for (eids, positions) in Query(world, (BallPosition,))
        @inbounds for i in eachindex(eids)
            idx += 1
            entities[idx] = eids[i]
            xs[idx] = positions[i].x
            ys[idx] = positions[i].y
        end
    end

    # Shuffle processing order (Fisher-Yates)
    resize!(system.order, n)
    for i in 1:n
        system.order[i] = i
    end
    for i in n:-1:2
        j = rand(rng, 1:i)
        system.order[i], system.order[j] = system.order[j], system.order[i]
    end

    # Process each ball sequentially; grid changes are visible immediately
    new_xs = Vector{Float64}(undef, n)
    new_ys = Vector{Float64}(undef, n)
    alive = falses(n)

    for ord_idx in 1:n
        ti = system.order[ord_idx]
        x = xs[ti]
        y = ys[ti]

        # Patch coordinates → 1-based grid indices
        # NetLogo patch-here uses round-half-up (Java Math.round),
        # not Julia's default banker's rounding.
        px = floor(Int, x + 0.5) + hw + 1
        py = floor(Int, y + 0.5) + hw + 1

        if px < 1 || px > dim || py < 1 || py > dim
            push!(system.to_kill, entities[ti])
            continue
        end

        if grid.triggered[px, py]
            # Patch already triggered → ball dies
            push!(system.to_kill, entities[ti])
        else
            # Trigger the patch
            grid.triggered[px, py] = true
            stats.traps_triggered += 1

            # hatch 1 [move]: offspring at current pos, then moves
            ox, oy = _mousetraps_move(x, y, rng, params.max_distance, hw)
            push!(system.to_spawn, (ox, oy))

            # Parent also calls move
            nx, ny = _mousetraps_move(x, y, rng, params.max_distance, hw)
            new_xs[ti] = nx
            new_ys[ti] = ny
            alive[ti] = true
        end
    end

    # Write back positions for surviving parents (before structural changes)
    idx = 0
    for (_, positions) in Query(world, (BallPosition,))
        @inbounds for i in eachindex(positions)
            idx += 1
            if alive[idx]
                positions[i].x = new_xs[idx]
                positions[i].y = new_ys[idx]
            end
        end
    end

    # Remove killed balls
    for eid in system.to_kill
        is_alive(world, eid) && remove_entity!(world, eid)
    end

    # Spawn offspring
    for (sx, sy) in system.to_spawn
        new_entity!(world, (BallPosition(sx, sy),))
    end

    return nothing
end

# --- Stats: update balls-in-air count ---

struct MousetrapStatsSystem <: System end

function update!(::MousetrapStatsSystem, world::World)
    stats = get_resource(world, MousetrapStats)
    count = 0
    for (eids, _) in Query(world, (BallPosition,))
        count += length(eids)
    end
    stats.balls_in_air = count
    return nothing
end

# --- Termination ---
# NetLogo: if not any? turtles [ stop ]

struct MousetrapTerminationSystem <: System end

function update!(::MousetrapTerminationSystem, world::World)
    params = get_resource(world, MousetrapParams)
    tick = get_resource(world, Tick)
    stats = get_resource(world, MousetrapStats)

    if stats.balls_in_air == 0 || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
