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

function _ti_signal_color(road::TIRoad, sz::Int, x::Int, y::Int, heading::Int)
    center = (sz + 1) ÷ 2
    # Red/green patches are near the center of intersection
    if road.stop_light == :north
        # North has green, east has red
        if heading == 0
            return :green
        else
            return :red
        end
    else
        if heading == 90
            return :green
        else
            return :red
        end
    end
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

    # Switch light if auto
    if params.auto
        cycle = params.green_length + params.yellow_length
        if cycle > 0 && tick_val % cycle == 0 && tick_val > 0
            road.stop_light = road.stop_light == :north ? :east : :north
        end
    end

    # Move existing cars
    car_list = Tuple{Entity, Int}[]
    for (eids, cars) in Query(world, (TICar,))
        @inbounds for i in eachindex(cars)
            push!(car_list, (eids[i], i))
        end
    end
    Random.shuffle!(rng, car_list)

    to_remove = Entity[]

    for (eid, _) in car_list
        car = get_components(world, eid, (TICar,))[1]

        # Compute clear distance ahead
        clear = _ti_clear_ahead(car, road, params, sz)

        if clear > car.speed
            if car.speed < params.speed_limit
                car.speed = min(car.speed + min(params.max_accel, clear - 1 - car.speed), params.speed_limit)
            end
            if car.speed > params.speed_limit
                car.speed = params.speed_limit
            end
        else
            car.speed = max(0, car.speed - min(params.max_brake, car.speed - (clear - 1)))
        end

        # Move
        road.occupancy[car.x, car.y] = zero_entity
        alive = true
        for _ in 1:car.speed
            dx, dy = _ti_heading_delta(car.heading)
            nx, ny = car.x + dx, car.y + dy
            # Off-grid -> die
            if nx < 1 || nx > sz || ny < 1 || ny > sz
                push!(to_remove, eid)
                alive = false
                break
            end
            # Accident
            if road.accidents[nx, ny] > 0
                road.accidents[nx, ny] = 5
                push!(to_remove, eid)
                alive = false
                break
            end
            car.x = nx
            car.y = ny
        end

        if alive
            # Check collision
            if !is_zero(road.occupancy[car.x, car.y]) && road.occupancy[car.x, car.y] != eid
                road.accidents[car.x, car.y] = 5
                stats.num_collisions += 1
                push!(to_remove, road.occupancy[car.x, car.y])
                push!(to_remove, eid)
            else
                road.occupancy[car.x, car.y] = eid
            end
        end
    end

    # Remove dead cars
    for eid in to_remove
        car_comp = get_components(world, eid, (TICar,))
        if !isempty(car_comp)
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

    # Decay accidents
    for i in eachindex(road.accidents)
        if road.accidents[i] > 0
            road.accidents[i] -= 1
        end
    end

    # Make new cars
    # Northbound: enters from bottom (y=1), at x=center
    if rand(rng) * 100.0 < params.freq_north
        spawn_x = center
        spawn_y = 1
        if _ti_is_road(sz, spawn_x, spawn_y) && is_zero(road.occupancy[spawn_x, spawn_y])
            spd = min(_ti_clear_ahead_at(spawn_x, spawn_y, 0, road, params, sz), params.speed_limit)
            eid = new_entity!(world, (TICar(spawn_x, spawn_y, 0, spd),))
            road.occupancy[spawn_x, spawn_y] = eid
        end
    end

    # Eastbound: enters from left (x=1), at y=center
    if rand(rng) * 100.0 < params.freq_east
        spawn_x = 1
        spawn_y = center
        if _ti_is_road(sz, spawn_x, spawn_y) && is_zero(road.occupancy[spawn_x, spawn_y])
            spd = min(_ti_clear_ahead_at(spawn_x, spawn_y, 90, road, params, sz), params.speed_limit)
            eid = new_entity!(world, (TICar(spawn_x, spawn_y, 90, spd),))
            road.occupancy[spawn_x, spawn_y] = eid
        end
    end

    _ti_update_stats!(world)
    return nothing
end

function _ti_heading_delta(heading::Int)
    if heading == 0   # north
        return (0, 1)
    else              # east
        return (1, 0)
    end
end

function _ti_clear_ahead(car::TICar, road::TIRoad, params::TIParams, sz::Int)
    return _ti_clear_ahead_at(car.x, car.y, car.heading, road, params, sz)
end

function _ti_clear_ahead_at(x::Int, y::Int, heading::Int, road::TIRoad, params::TIParams, sz::Int)
    dx, dy = _ti_heading_delta(heading)
    center = (sz + 1) ÷ 2
    n = 1
    max_look = params.max_accel + params.speed_limit
    for _ in 1:max_look
        nx, ny = x + n * dx, y + n * dy
        if nx < 1 || nx > sz || ny < 1 || ny > sz
            return n
        end
        # Check for red light
        if _ti_is_intersection(sz, nx, ny)
            sig = _ti_signal_color(road, sz, nx, ny, heading)
            if sig == :red
                return n
            end
        end
        # Check for obstacle
        if road.accidents[nx, ny] > 0 || !is_zero(road.occupancy[nx, ny])
            return n
        end
        n += 1
    end
    return n
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
