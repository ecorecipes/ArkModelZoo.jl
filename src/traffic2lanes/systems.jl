# --- Initialization ---

struct InitT2LSystem <: System end

function initialize!(::InitT2LSystem, world::World)
    params = get_resource(world, T2LParams)
    rng = get_resource(world, RNGResource).rng
    road = get_resource(world, T2LRoad)
    len = road.length

    for i in 1:params.number
        lane = rand(rng, 0:1)
        speed = 0.1 + rand(rng) * 9.9
        speed_limit = (rand(rng, 0:10) / 10.0) + 1.0
        max_pat = rand(rng, 10:59)
        patience = max_pat - rand(rng, 0:9)
        target_lane = lane

        car = T2LCar(0, lane, speed, speed_limit, patience, max_pat, target_lane, false)

        # Place on empty spot
        placed = false
        positions = collect(1:len)
        Random.shuffle!(rng, positions)
        for x in positions
            occ = lane == 0 ? road.lane0 : road.lane1
            if is_zero(occ[x])
                car.x = x
                eid = new_entity!(world, (car,))
                occ[x] = eid
                placed = true
                break
            end
        end
        if !placed
            # Try other lane
            other_lane = 1 - lane
            car.lane = other_lane
            car.target_lane = other_lane
            occ = other_lane == 0 ? road.lane0 : road.lane1
            for x in positions
                if is_zero(occ[x])
                    car.x = x
                    eid = new_entity!(world, (car,))
                    occ[x] = eid
                    placed = true
                    break
                end
            end
        end
    end
    return nothing
end

# --- Go (Drive) ---

struct T2LGoSystem <: System end

function update!(::T2LGoSystem, world::World)
    params = get_resource(world, T2LParams)
    rng = get_resource(world, RNGResource).rng
    road = get_resource(world, T2LRoad)
    stats = get_resource(world, T2LStats)
    len = road.length
    accel = params.speed_up / 1000.0
    decel = params.slow_down / 1000.0

    # Collect all cars
    car_list = Tuple{Entity, Int}[]
    for (eids, cars) in Query(world, (T2LCar,))
        @inbounds for i in eachindex(cars)
            push!(car_list, (eids[i], i))
        end
    end
    Random.shuffle!(rng, car_list)

    num_changes = 0
    total_speed = 0.0

    for (eid, _) in car_list
        car = get_components(world, eid, (T2LCar,))[1]
        occ = car.lane == 0 ? road.lane0 : road.lane1

        # Check car ahead at +1
        ahead_x = mod1(car.x + 1, len)
        if !is_zero(occ[ahead_x])
            ahead_car = get_components(world, occ[ahead_x], (T2LCar,))[1]
            car.speed = ahead_car.speed
            car.speed = max(0.01, car.speed - decel)
        else
            if params.look_ahead == 2
                ahead2_x = mod1(car.x + 2, len)
                if !is_zero(occ[ahead2_x])
                    ahead_car = get_components(world, occ[ahead2_x], (T2LCar,))[1]
                    car.speed = ahead_car.speed
                    car.speed = max(0.01, car.speed - decel)
                else
                    car.speed = min(car.speed + accel, car.speed_limit)
                end
            else
                car.speed = min(car.speed + accel, car.speed_limit)
            end
        end

        car.speed = clamp(car.speed, 0.01, car.speed_limit)

        # Signal / lane change logic
        if !car.change
            # Signal: want to change if car ahead is slower
            if !is_zero(occ[ahead_x]) && occ[ahead_x] != eid
                ahead_car = get_components(world, occ[ahead_x], (T2LCar,))[1]
                if ahead_car.speed < car.speed
                    car.change = true
                end
            end
        else
            # Attempt lane change
            if car.patience <= 0
                car.max_patience = max(1, car.max_patience - rand(rng, 0:4))
                car.patience = car.max_patience
                car.target_lane = 1 - car.target_lane
                car.lane = 1 - car.lane  # swap desire
            else
                car.patience -= 1
            end

            if car.target_lane != car.lane
                # Try to move to target lane
                target_occ = car.target_lane == 0 ? road.lane0 : road.lane1
                if is_zero(target_occ[car.x])
                    # Move lane
                    occ[car.x] = zero_entity
                    car.lane = car.target_lane
                    new_occ = car.lane == 0 ? road.lane0 : road.lane1
                    new_occ[car.x] = eid
                    car.change = false
                    num_changes += 1
                    occ = new_occ  # update reference
                end
            else
                car.target_lane = 1 - car.lane
                car.change = false
            end
        end

        # Move forward
        occ_current = car.lane == 0 ? road.lane0 : road.lane1
        steps = round(Int, car.speed)
        steps = max(steps, 0)
        for _ in 1:steps
            new_x = mod1(car.x + 1, len)
            if is_zero(occ_current[new_x])
                occ_current[car.x] = zero_entity
                car.x = new_x
                occ_current[car.x] = eid
            else
                car.speed = 0.01
                break
            end
        end

        total_speed += car.speed
    end

    n = length(car_list)
    stats.mean_speed = n > 0 ? total_speed / n : 0.0
    stats.num_lane_changes = num_changes
    return nothing
end

# --- Termination ---

struct T2LTerminationSystem <: System end

function update!(::T2LTerminationSystem, world::World)
    params = get_resource(world, T2LParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
