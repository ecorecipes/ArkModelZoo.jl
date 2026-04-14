# --- Initialization ---

struct InitTISystem <: System end

function initialize!(::InitTISystem, world::World)
    params = get_resource(world, TIParams)
    road = get_resource(world, TIRoad)
    road.stop_light = :north
    _ti_update_stats!(world)
    return nothing
end

function _ti_is_road(sz::Int, x::Int, y::Int)
    center = (sz + 1) ÷ 2
    return abs(x - center) <= 1 || abs(y - center) <= 1
end

function _ti_is_intersection(sz::Int, x::Int, y::Int)
    center = (sz + 1) ÷ 2
    return abs(x - center) <= 1 && abs(y - center) <= 1
end

function _ti_update_stats!(world::World)
    stats = get_resource(world, TIStats)
    waiting = 0
    waiting_e = 0
    waiting_n = 0
    for (_, cars) in Query(world, (TICar,))
        @inbounds for i in eachindex(cars)
            c = cars[i]
            if c.speed == 0
                waiting += 1
                if c.heading == 90
                    waiting_e += 1
                elseif c.heading == 0
                    waiting_n += 1
                end
            end
        end
    end
    stats.waiting_overall = waiting
    stats.waiting_eastbound = waiting_e
    stats.waiting_northbound = waiting_n
end

# --- Helpers ---

@inline function _ti_heading_delta(heading::Int)
    heading == 0 ? (0, 1) : (1, 0)
end

# NetLogo signal patches:
#   stop_light="north" → patch (0,-1)=red, patch (-1,0)=green   (north STOPPED)
#   stop_light="east"  → patch (0,-1)=green, patch (-1,0)=red   (east STOPPED)
# In Ark coords (center=18): (0,-1)=(center, center-1)=(18,17), (-1,0)=(center-1, center)=(17,18)
#
# The OLD Ark convention: stop_light=:north means "north has GREEN" (opposite of NL).
# Combined with switch-at-start + tick>0 guard, the signal timing is accidentally correct.
# We keep the OLD convention and just fix the red-patch check to match NL's single-patch behavior.
#
# OLD :north (north GREEN, east RED) matches NL "east" → red at (-1,0) = Ark (17,18)
# OLD :east  (east GREEN, north RED) matches NL "north" → red at (0,-1) = Ark (18,17)
@inline function _ti_is_red_patch(road::TIRoad, center::Int, x::Int, y::Int)
    if road.stop_light == :north
        # East is stopped → red at Ark (center-1, center) = NL (-1, 0)
        return x == center - 1 && y == center
    else
        # North is stopped → red at Ark (center, center-1) = NL (0, -1)
        return x == center && y == center - 1
    end
end

# NetLogo clear-ahead: look max-accel + speed patches ahead.
# Reports distance to first obstacle (red patch, orange/accident, or turtle).
function _ti_clear_ahead(car::TICar, road::TIRoad, params::TIParams, sz::Int)
    return _ti_clear_ahead_at(car.x, car.y, car.heading, car.speed, road, params, sz)
end

function _ti_clear_ahead_at(x::Int, y::Int, heading::Int, speed::Int,
                            road::TIRoad, params::TIParams, sz::Int)
    dx, dy = _ti_heading_delta(heading)
    center = (sz + 1) ÷ 2
    n = 1
    max_look = params.max_accel + speed
    for _ in 1:max_look
        nx, ny = x + n * dx, y + n * dy
        if nx < 1 || nx > sz || ny < 1 || ny > sz
            break
        end
        if _ti_is_red_patch(road, center, nx, ny) ||
           road.accidents[nx, ny] > 0 ||
           !is_zero(road.occupancy[nx, ny])
            return n
        end
        n += 1
    end
    return n
end

# --- Go ---

struct TIGoSystem <: System end

function update!(::TIGoSystem, world::World)
    params = get_resource(world, TIParams)
    rng = get_resource(world, RNGResource).rng
    road = get_resource(world, TIRoad)
    stats = get_resource(world, TIStats)
    sz = road.size
    tick_val = get_resource(world, Tick).tick
    center = (sz + 1) ÷ 2

    # Switch light FIRST (OLD order — accidentally correct with OLD signal semantics)
    if params.auto
        cycle = params.green_length + params.yellow_length
        if cycle > 0 && tick_val % cycle == 0 && tick_val > 0
            road.stop_light = road.stop_light == :north ? :east : :north
        end
    end

    # ── 1. move-cars: ask turtles [move] then check-for-collisions ──
    car_list = Tuple{Entity, Int}[]
    for (eids, cars) in Query(world, (TICar,))
        @inbounds for i in eachindex(cars)
            push!(car_list, (eids[i], i))
        end
    end
    Random.shuffle!(rng, car_list)

    dead_set = Set{Entity}()

    for (eid, _) in car_list
        eid in dead_set && continue
        car_comp = try
            get_components(world, eid, (TICar,))
        catch
            nothing
        end
        (car_comp === nothing || isempty(car_comp)) && continue
        car = car_comp[1]

        # clear-ahead
        clear = _ti_clear_ahead(car, road, params, sz)

        # Speed adjustment (matches NetLogo move procedure)
        if clear > car.speed
            if car.speed < params.speed_limit
                car.speed = car.speed + min(params.max_accel, clear - 1 - car.speed)
            end
            if car.speed > params.speed_limit
                car.speed = params.speed_limit
            end
        else
            car.speed = car.speed - min(params.max_brake, car.speed - (clear - 1))
            if car.speed < 0; car.speed = 0; end
        end

        # Move: repeat speed [fd 1; if not can-move? 1 [die]; if pcolor = orange [die]]
        if road.occupancy[car.x, car.y] == eid
            road.occupancy[car.x, car.y] = zero_entity
        end
        alive = true
        for _ in 1:car.speed
            dx, dy = _ti_heading_delta(car.heading)
            nx, ny = car.x + dx, car.y + dy
            if nx < 1 || nx > sz || ny < 1 || ny > sz
                push!(dead_set, eid)
                alive = false
                break
            end
            if road.accidents[nx, ny] > 0
                road.accidents[nx, ny] = 5
                push!(dead_set, eid)
                alive = false
                break
            end
            car.x = nx
            car.y = ny
            # can-move? 1: check if NEXT step would be off-grid
            nnx, nny = nx + dx, ny + dy
            if nnx < 1 || nnx > sz || nny < 1 || nny > sz
                push!(dead_set, eid)
                alive = false
                break
            end
        end

        if alive
            # Inline collision: if another car already at this position
            if !is_zero(road.occupancy[car.x, car.y]) && road.occupancy[car.x, car.y] != eid
                other = road.occupancy[car.x, car.y]
                road.accidents[car.x, car.y] = 5
                road.occupancy[car.x, car.y] = zero_entity
                push!(dead_set, other)
                push!(dead_set, eid)
            else
                road.occupancy[car.x, car.y] = eid
            end
        end
    end

    # check-for-collisions: decay old accidents
    for i in eachindex(road.accidents)
        if road.accidents[i] > 0
            road.accidents[i] -= 1
        end
    end

    # Remove dead cars
    for eid in dead_set
        car_comp = try
            get_components(world, eid, (TICar,))
        catch
            nothing
        end
        if car_comp !== nothing && !isempty(car_comp)
            c = car_comp[1]
            if c.x >= 1 && c.x <= sz && c.y >= 1 && c.y <= sz
                if road.occupancy[c.x, c.y] == eid
                    road.occupancy[c.x, c.y] = zero_entity
                end
            end
        end
        try
            remove_entity!(world, eid)
        catch
        end
    end

    # ── 2. make-new-cars ──
    if rand(rng) * 100.0 < params.freq_north
        spawn_x = center
        spawn_y = 1
        if is_zero(road.occupancy[spawn_x, spawn_y])
            spd = min(_ti_clear_ahead_at(spawn_x, spawn_y, 0, 0, road, params, sz),
                      params.speed_limit)
            eid = new_entity!(world, (TICar(spawn_x, spawn_y, 0, spd),))
            road.occupancy[spawn_x, spawn_y] = eid
        end
    end

    if rand(rng) * 100.0 < params.freq_east
        spawn_x = 1
        spawn_y = center
        if is_zero(road.occupancy[spawn_x, spawn_y])
            spd = min(_ti_clear_ahead_at(spawn_x, spawn_y, 90, 0, road, params, sz),
                      params.speed_limit)
            eid = new_entity!(world, (TICar(spawn_x, spawn_y, 90, spd),))
            road.occupancy[spawn_x, spawn_y] = eid
        end
    end

    # ── 3. Update stats ──
    _ti_update_stats!(world)
    return nothing
end

# --- Termination ---

struct TITerminationSystem <: System end

function update!(::TITerminationSystem, world::World)
    params = get_resource(world, TIParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
