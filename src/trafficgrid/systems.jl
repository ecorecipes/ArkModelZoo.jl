# --- Initialization ---

struct InitTGSystem <: System end

function initialize!(::InitTGSystem, world::World)
    params = get_resource(world, TGParams)
    rng = get_resource(world, RNGResource).rng
    road = get_resource(world, TGRoad)
    w, h = road.width, road.height
    gxi = w ÷ params.grid_size_x
    gyi = h ÷ params.grid_size_y

    # Setup roads and intersections
    for x in 1:w, y in 1:h
        is_r = ((x - 1) % gxi == 0) || ((y - 1) % gyi == 0)
        road.is_road[x, y] = is_r
        if ((x - 1) % gxi == 0) && ((y - 1) % gyi == 0)
            road.is_intersection[x, y] = true
            road.green_light_up[x, y] = true
            road.my_phase[x, y] = 0
        end
    end

    # Setup signal colors
    _tg_update_all_signals!(road, params)

    # Place cars on road patches
    road_patches = [(x, y) for x in 1:w for y in 1:h if road.is_road[x, y]]
    Random.shuffle!(rng, road_patches)
    n_cars = min(params.num_cars, length(road_patches))
    occupancy = fill(zero_entity, w, h)

    for i in 1:n_cars
        rx, ry = road_patches[i]
        # Determine direction based on position
        up_car = ((rx - 1) % gxi == 0)  # on vertical road
        if road.is_intersection[rx, ry]
            up_car = rand(rng, Bool)
        end
        speed = 0.0
        eid = new_entity!(world, (TGCar(rx, ry, speed, up_car, 0),))
        occupancy[rx, ry] = eid
    end
    add_resource!(world, occupancy)
    return nothing
end

function _tg_update_all_signals!(road::TGRoad, params::TGParams)
    w, h = road.width, road.height
    for x in 1:w, y in 1:h
        if road.is_intersection[x, y]
            if params.power
                if road.green_light_up[x, y]
                    road.signal_color_ns[x, y] = 1  # green
                    road.signal_color_ew[x, y] = 0  # red
                else
                    road.signal_color_ns[x, y] = 0
                    road.signal_color_ew[x, y] = 1
                end
            else
                road.signal_color_ns[x, y] = 2  # off
                road.signal_color_ew[x, y] = 2
            end
        end
    end
end

# --- Go ---

struct TGGoSystem <: System end

function update!(::TGGoSystem, world::World)
    params = get_resource(world, TGParams)
    rng = get_resource(world, RNGResource).rng
    road = get_resource(world, TGRoad)
    stats = get_resource(world, TGStats)
    tick_val = get_resource(world, Tick).tick
    w, h = road.width, road.height
    occupancy = get_resource(world, Matrix{Entity})
    accel = 0.099

    # Set signals
    phase = tick_val % params.ticks_per_cycle
    for x in 1:w, y in 1:h
        if road.is_intersection[x, y] && road.my_phase[x, y] >= 0
            mp = road.my_phase[x, y]
            if phase == (mp * params.ticks_per_cycle) ÷ 100
                road.green_light_up[x, y] = !road.green_light_up[x, y]
            end
        end
    end
    _tg_update_all_signals!(road, params)

    num_stopped = 0
    total_speed = 0.0
    total_wait = 0.0
    n_cars = 0

    # Collect cars
    cars = Tuple{Entity, Int}[]
    for (eids, cardata) in Query(world, (TGCar,))
        @inbounds for i in eachindex(cardata)
            push!(cars, (eids[i], i))
        end
    end
    Random.shuffle!(rng, cars)

    for (eid, _) in cars
        car = get_components(world, eid, (TGCar,))[1]
        n_cars += 1
        cx, cy = car.x, car.y

        # Check if at red light
        at_red = false
        if road.is_intersection[cx, cy] || _tg_near_intersection(road, cx, cy)
            ix, iy = _tg_nearest_intersection(road, cx, cy)
            if ix > 0
                if car.up_car && road.signal_color_ns[ix, iy] == 0
                    at_red = true
                elseif !car.up_car && road.signal_color_ew[ix, iy] == 0
                    at_red = true
                end
            end
        end

        if at_red
            car.speed = 0.0
        else
            # Check ahead
            if car.up_car
                nx, ny = cx, mod1(cy - 1, h)
            else
                nx, ny = mod1(cx + 1, w), cy
            end
            if !is_zero(occupancy[nx, ny]) && occupancy[nx, ny] != eid
                ahead_car = get_components(world, occupancy[nx, ny], (TGCar,))[1]
                if ahead_car.up_car == car.up_car
                    car.speed = max(0.0, ahead_car.speed - accel)
                else
                    car.speed = 0.0
                end
            else
                car.speed = min(car.speed + accel, params.speed_limit)
            end
        end

        # Move
        if car.speed > 0.0
            if car.up_car
                new_x, new_y = cx, mod1(cy - 1, h)
            else
                new_x, new_y = mod1(cx + 1, w), cy
            end
            if is_zero(occupancy[new_x, new_y]) || occupancy[new_x, new_y] == eid
                occupancy[cx, cy] = zero_entity
                occupancy[new_x, new_y] = eid
                car.x = new_x
                car.y = new_y
            else
                car.speed = 0.0
            end
        end

        # Record data
        if car.speed == 0.0
            num_stopped += 1
            car.wait_time += 1
        else
            car.wait_time = 0
        end
        total_speed += car.speed
        total_wait += car.wait_time
    end

    stats.num_cars_stopped = num_stopped
    stats.mean_speed = n_cars > 0 ? total_speed / n_cars : 0.0
    stats.mean_wait_time = n_cars > 0 ? total_wait / n_cars : 0.0
    return nothing
end

function _tg_near_intersection(road::TGRoad, x::Int, y::Int)
    w, h = road.width, road.height
    for dx in -1:1, dy in -1:1
        (dx == 0 && dy == 0) && continue
        nx = mod1(x + dx, w)
        ny = mod1(y + dy, h)
        if road.is_intersection[nx, ny]
            return true
        end
    end
    return false
end

function _tg_nearest_intersection(road::TGRoad, x::Int, y::Int)
    w, h = road.width, road.height
    if road.is_intersection[x, y]
        return (x, y)
    end
    for dx in -1:1, dy in -1:1
        (dx == 0 && dy == 0) && continue
        nx = mod1(x + dx, w)
        ny = mod1(y + dy, h)
        if road.is_intersection[nx, ny]
            return (nx, ny)
        end
    end
    return (0, 0)
end

# --- Termination ---

struct TGTerminationSystem <: System end

function update!(::TGTerminationSystem, world::World)
    params = get_resource(world, TGParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
