# ── Helper functions for NetLogo heading math ──

# NetLogo heading: 0=north, 90=east, clockwise
# NetLogo dx = sin(heading°), dy = cos(heading°)

function _nl_heading_to_rad(h::Float64)
    return h * π / 180.0
end

function _nl_dx(h::Float64)
    return sin(_nl_heading_to_rad(h))
end

function _nl_dy(h::Float64)
    return cos(_nl_heading_to_rad(h))
end

# NetLogo atan x y → heading in [0, 360)
function _nl_atan(x::Float64, y::Float64)
    if x == 0.0 && y == 0.0
        return 0.0
    end
    a = atan(x, y) * 180.0 / π
    return mod(a, 360.0)
end

# subtract-headings h1 h2 → difference in [-180, 180]
function _subtract_headings(h1::Float64, h2::Float64)
    diff = mod(h1 - h2, 360.0)
    if diff > 180.0
        diff -= 360.0
    end
    return diff
end

# Toroidal distance
function _torus_dist(x1::Float64, y1::Float64, x2::Float64, y2::Float64, w::Float64, h::Float64)
    dx = abs(x1 - x2)
    dy = abs(y1 - y2)
    dx = min(dx, w - dx)
    dy = min(dy, h - dy)
    return sqrt(dx * dx + dy * dy)
end

# Toroidal shortest displacement from (x1,y1) to (x2,y2)
function _torus_dx_dy(x1::Float64, y1::Float64, x2::Float64, y2::Float64, w::Float64, h::Float64)
    dx = x2 - x1
    if dx > w / 2.0
        dx -= w
    elseif dx < -w / 2.0
        dx += w
    end
    dy = y2 - y1
    if dy > h / 2.0
        dy -= h
    elseif dy < -h / 2.0
        dy += h
    end
    return dx, dy
end

# NetLogo towards: heading from (x1,y1) to (x2,y2) on torus
function _nl_towards(x1::Float64, y1::Float64, x2::Float64, y2::Float64, w::Float64, h::Float64)
    dx, dy = _torus_dx_dy(x1, y1, x2, y2, w, h)
    return _nl_atan(dx, dy)
end

# turn-at-most: clamp turn to max_turn degrees
function _turn_at_most(turn::Float64, max_turn::Float64)
    if abs(turn) > max_turn
        return turn > 0.0 ? max_turn : -max_turn
    else
        return turn
    end
end

# ── Initialization ──

struct InitFlockingSystem <: System end

function initialize!(::InitFlockingSystem, world::World)
    params = get_resource(world, FlockingParams)
    rng = get_resource(world, RNGResource).rng
    w = Float64(params.grid_width)
    h = Float64(params.grid_height)
    half_w = w / 2.0
    half_h = h / 2.0

    for _ in 1:params.population
        # random-xcor/ycor in NetLogo for 91x91 world: [-45, 45)
        x = rand(rng) * w - half_w
        y = rand(rng) * h - half_h
        # crt gives random integer heading [0, 359]
        heading = Float64(rand(rng, 0:359))
        new_entity!(world, (
            FlockPosition(x, y),
            FlockHeading(heading),
        ))
    end
    return nothing
end

# ── Flock System (ask turtles [flock]) ──

struct FlockSystem <: System
    order::Vector{Int}
end
FlockSystem() = FlockSystem(Int[])

function update!(system::FlockSystem, world::World)
    params = get_resource(world, FlockingParams)
    rng = get_resource(world, RNGResource).rng
    w = Float64(params.grid_width)
    h = Float64(params.grid_height)
    vision = params.vision
    min_sep = params.minimum_separation

    # Collect all entities into flat arrays for O(n²) access
    n = 0
    for (eids, _, _) in Query(world, (FlockPosition, FlockHeading))
        n += length(eids)
    end
    n == 0 && return nothing

    entities = Vector{Entity}(undef, n)
    positions_x = Vector{Float64}(undef, n)
    positions_y = Vector{Float64}(undef, n)
    headings = Vector{Float64}(undef, n)

    idx = 0
    for (eids, positions, heads) in Query(world, (FlockPosition, FlockHeading))
        @inbounds for i in eachindex(eids)
            idx += 1
            entities[idx] = eids[i]
            positions_x[idx] = positions[i].x
            positions_y[idx] = positions[i].y
            headings[idx] = heads[i].angle
        end
    end

    # Shuffled order for sequential processing
    resize!(system.order, n)
    for i in 1:n
        system.order[i] = i
    end
    for i in n:-1:2
        j = rand(rng, 1:i)
        system.order[i], system.order[j] = system.order[j], system.order[i]
    end

    # Pre-allocate flockmate buffer
    flockmates = Int[]

    for ord_idx in 1:n
        ti = system.order[ord_idx]
        tx = positions_x[ti]
        ty = positions_y[ti]

        # find-flockmates: other turtles in-radius vision (toroidal)
        empty!(flockmates)
        for j in 1:n
            j == ti && continue
            d = _torus_dist(tx, ty, positions_x[j], positions_y[j], w, h)
            if d <= vision
                push!(flockmates, j)
            end
        end

        isempty(flockmates) && continue

        # find-nearest-neighbor
        nearest = flockmates[1]
        nearest_dist = _torus_dist(tx, ty, positions_x[nearest], positions_y[nearest], w, h)
        for k in 2:length(flockmates)
            fj = flockmates[k]
            d = _torus_dist(tx, ty, positions_x[fj], positions_y[fj], w, h)
            if d < nearest_dist
                nearest = fj
                nearest_dist = d
            end
        end

        if nearest_dist < min_sep
            # separate: turn-away nearest-neighbor's heading
            nn_heading = headings[nearest]
            turn = _subtract_headings(headings[ti], nn_heading)
            delta = _turn_at_most(turn, params.max_separate_turn)
            headings[ti] = mod(headings[ti] + delta, 360.0)
        else
            # align: turn-towards average-flockmate-heading
            sum_dx = 0.0
            sum_dy = 0.0
            for fj in flockmates
                sum_dx += _nl_dx(headings[fj])
                sum_dy += _nl_dy(headings[fj])
            end
            avg_flock_heading = _nl_atan(sum_dx, sum_dy)
            turn_align = _subtract_headings(avg_flock_heading, headings[ti])
            delta_align = _turn_at_most(turn_align, params.max_align_turn)
            headings[ti] = mod(headings[ti] + delta_align, 360.0)

            # cohere: turn-towards average-heading-towards-flockmates
            nf = length(flockmates)
            sum_sin = 0.0
            sum_cos = 0.0
            for fj in flockmates
                # towards myself + 180 from each flockmate's perspective
                towards_me = _nl_towards(positions_x[fj], positions_y[fj], tx, ty, w, h)
                angle_away = towards_me + 180.0
                sum_sin += sin(angle_away * π / 180.0)
                sum_cos += cos(angle_away * π / 180.0)
            end
            mean_sin = sum_sin / nf
            mean_cos = sum_cos / nf
            avg_heading_towards = _nl_atan(mean_sin, mean_cos)
            turn_cohere = _subtract_headings(avg_heading_towards, headings[ti])
            delta_cohere = _turn_at_most(turn_cohere, params.max_cohere_turn)
            headings[ti] = mod(headings[ti] + delta_cohere, 360.0)
        end
    end

    # Write headings back to world
    idx = 0
    for (_, _, heads) in Query(world, (FlockPosition, FlockHeading))
        @inbounds for i in eachindex(heads)
            idx += 1
            heads[i].angle = headings[idx]
        end
    end
    return nothing
end

# ── Movement System: repeat 5 [ask turtles [fd 0.2]] ──

struct FlockMoveSystem <: System end

function update!(::FlockMoveSystem, world::World)
    params = get_resource(world, FlockingParams)
    w = Float64(params.grid_width)
    h = Float64(params.grid_height)
    half_w = w / 2.0
    half_h = h / 2.0

    for _ in 1:5
        for (_, positions, heads) in Query(world, (FlockPosition, FlockHeading))
            @inbounds for i in eachindex(positions)
                θ = _nl_heading_to_rad(heads[i].angle)
                positions[i].x += sin(θ) * 0.2
                positions[i].y += cos(θ) * 0.2
                # Wrap toroidally to [-half_w, half_w) and [-half_h, half_h)
                positions[i].x = mod(positions[i].x + half_w, w) - half_w
                positions[i].y = mod(positions[i].y + half_h, h) - half_h
            end
        end
    end
    return nothing
end

# ── Stats System ──

struct FlockStatsSystem <: System end

function update!(::FlockStatsSystem, world::World)
    stats = get_resource(world, FlockStats)
    total = 0
    sum_heading = 0.0

    for (_, _, heads) in Query(world, (FlockPosition, FlockHeading))
        @inbounds for i in eachindex(heads)
            sum_heading += heads[i].angle
            total += 1
        end
    end

    # mean [heading] of turtles is arithmetic mean in NetLogo
    stats.avg_heading = total > 0 ? sum_heading / total : 0.0
    return nothing
end

# ── Termination System ──

struct FlockTerminationSystem <: System end

function update!(::FlockTerminationSystem, world::World)
    params = get_resource(world, FlockingParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
