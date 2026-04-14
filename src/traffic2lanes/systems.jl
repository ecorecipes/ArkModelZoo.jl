# --- Initialization ---

struct InitT2LSystem <: System end

function initialize!(::InitT2LSystem, world::World)
    params = get_resource(world, T2LParams)
    rng = get_resource(world, RNGResource).rng
    road = get_resource(world, T2LRoad)
    len = road.length

    for i in 1:params.number
        lane = rand(rng, 0:1)
        pycor = lane == 0 ? -2 : 2
        # NetLogo: random 9.9 truncates to random 9 → integer 0..8
        speed = 0.1 + Float64(rand(rng, 0:8))
        speed_limit = (rand(rng, 0:10) / 10.0) + 1.0
        max_pat = rand(rng, 0:49) + 10
        patience = max_pat - rand(rng, 0:9)
        target_lane = lane

        car = T2LCar(0, pycor, lane, speed, speed_limit, patience, max_pat, target_lane, false)

        # Place on empty spot — NetLogo: move-to one-of patches with [...not any? turtles-here]
        # then loop { if other turtles-here fd 1 else stop }
        row = pycor_to_row(pycor)
        placed = false
        # Try random-xcor then fd 1 loop (wrapping)
        start_x = rand(rng, 1:len)
        for offset in 0:(len-1)
            x = mod1(start_x + offset, len)
            if is_zero(road.occ[x, row])
                car.x = x
                eid = new_entity!(world, (car,))
                road.occ[x, row] = eid
                placed = true
                break
            end
        end
        if !placed
            # Try other lane
            other_lane = 1 - lane
            other_pycor = other_lane == 0 ? -2 : 2
            other_row = pycor_to_row(other_pycor)
            car.lane = other_lane
            car.pycor = other_pycor
            car.target_lane = other_lane
            for offset in 0:(len-1)
                x = mod1(start_x + offset, len)
                if is_zero(road.occ[x, other_row])
                    car.x = x
                    eid = new_entity!(world, (car,))
                    road.occ[x, other_row] = eid
                    placed = true
                    break
                end
            end
        end
    end
    # Compute initial stats (matching NetLogo's update-tracked-globals in setup)
    stats = get_resource(world, T2LStats)
    total_speed = 0.0
    n = 0
    for (_, cars) in Query(world, (T2LCar,))
        for c in cars
            total_speed += c.speed
            n += 1
        end
    end
    stats.mean_speed = n > 0 ? total_speed / n : 0.0
    return nothing
end

struct T2LGoSystem <: System end

# Helper: get entity at (pxcor+dx, pycor+dy) with x-wrapping, no y-wrapping
@inline function turtles_at(road::T2LRoad, x::Int, py::Int, dx::Int, dy::Int)
    new_py = py + dy
    if new_py < -2 || new_py > 2
        return zero_entity
    end
    new_x = mod1(x + dx, road.length)
    return road.occ[new_x, pycor_to_row(new_py)]
end

function update!(::T2LGoSystem, world::World)
    params = get_resource(world, T2LParams)
    rng = get_resource(world, RNGResource).rng
    road = get_resource(world, T2LRoad)
    stats = get_resource(world, T2LStats)
    len = road.length
    accel = params.speed_up / 1000.0
    decel = params.slow_down / 1000.0

    num_changes = 0

    # Collect all cars
    car_list = Tuple{Entity, Int}[]
    for (eids, cars) in Query(world, (T2LCar,))
        @inbounds for i in eachindex(cars)
            push!(car_list, (eids[i], i))
        end
    end
    Random.shuffle!(rng, car_list)

    total_speed = 0.0

    for (eid, _) in car_list
        car = get_components(world, eid, (T2LCar,))[1]

        # ── Speed adjustment: turtles-at 1 0 checks (pxcor+1, same pycor) ──
        ahead_eid = turtles_at(road, car.x, car.pycor, 1, 0)
        if !is_zero(ahead_eid) && ahead_eid != eid
            ahead_car = get_components(world, ahead_eid, (T2LCar,))[1]
            car.speed = ahead_car.speed
            car.speed -= decel  # decelerate
        else
            if params.look_ahead == 2
                ahead2_eid = turtles_at(road, car.x, car.pycor, 2, 0)
                if !is_zero(ahead2_eid) && ahead2_eid != eid
                    ahead2_car = get_components(world, ahead2_eid, (T2LCar,))[1]
                    car.speed = ahead2_car.speed
                    car.speed -= decel
                else
                    car.speed += accel  # accelerate
                end
            else
                car.speed += accel
            end
        end
        if car.speed < 0.01; car.speed = 0.01; end
        if car.speed > car.speed_limit; car.speed = car.speed_limit; end

        # ── Signal / Change lanes ──
        if !car.change
            # signal procedure
            ahead_eid = turtles_at(road, car.x, car.pycor, 1, 0)
            if !is_zero(ahead_eid) && ahead_eid != eid
                ahead_car = get_components(world, ahead_eid, (T2LCar,))[1]
                if ahead_car.speed < car.speed
                    car.change = true
                end
                # if ahead_car.speed >= car.speed, change? unchanged
            else
                car.change = false
            end
        else
            # change-lanes procedure
            if car.patience <= 0
                if car.max_patience <= 1
                    car.max_patience = rand(rng, 0:9) + 1
                else
                    car.max_patience = car.max_patience - rand(rng, 0:4)
                end
                car.patience = car.max_patience
                if car.target_lane == 0
                    car.target_lane = 1
                    car.lane = 0
                else
                    car.target_lane = 0
                    car.lane = 1
                end
            else
                car.patience -= 1
            end

            if car.target_lane == car.lane
                if car.target_lane == 0
                    car.target_lane = 1
                    car.change = false
                else
                    car.target_lane = 0
                    car.change = false
                end
            else
                target_pycor = car.target_lane == 1 ? 2 : -2
                if car.pycor == target_pycor
                    # Arrived at target lane
                    car.lane = car.target_lane
                    car.change = false
                    num_changes += 1
                else
                    # Move toward target pycor
                    dy = car.target_lane == 1 ? 1 : -1
                    next_py = car.pycor + dy
                    next_row = pycor_to_row(next_py)
                    cur_row = pycor_to_row(car.pycor)
                    # turtles-at 0 dy
                    up_eid = road.occ[car.x, next_row]
                    if is_zero(up_eid) || up_eid == eid
                        # Move up/down
                        road.occ[car.x, cur_row] = zero_entity
                        car.pycor = next_py
                        road.occ[car.x, next_row] = eid
                    else
                        # Blocked vertically — try forward: turtles-at 1 0
                        fwd_eid = turtles_at(road, car.x, car.pycor, 1, 0)
                        if is_zero(fwd_eid) || fwd_eid == eid
                            old_x = car.x
                            car.x = mod1(car.x + 1, len)
                            road.occ[old_x, cur_row] = zero_entity
                            road.occ[car.x, cur_row] = eid
                        else
                            # Blocked both ways — decelerate
                            car.speed -= decel
                            if car.speed <= 0
                                car.speed = 0.1
                            end
                        end
                    end
                end
            end
        end

        # ── Final movement (3-way decision) ──
        # Re-check from current (possibly updated) position
        ahead_eid = turtles_at(road, car.x, car.pycor, 1, 0)
        cur_row = pycor_to_row(car.pycor)
        if !is_zero(ahead_eid) && ahead_eid != eid
            # Car at +1: match speed, don't move
            # NetLogo: and (xcor != min-pxcor - .5) — always true since xcor >= min-pxcor
            ahead_car = get_components(world, ahead_eid, (T2LCar,))[1]
            car.speed = ahead_car.speed
        else
            ahead2_eid = turtles_at(road, car.x, car.pycor, 2, 0)
            if !is_zero(ahead2_eid) && ahead2_eid != eid && car.speed > 1.0
                # Car at +2, speed > 1: match speed, fd 1
                ahead2_car = get_components(world, ahead2_eid, (T2LCar,))[1]
                car.speed = ahead2_car.speed
                old_x = car.x
                car.x = mod1(car.x + 1, len)
                road.occ[old_x, cur_row] = zero_entity
                road.occ[car.x, cur_row] = eid
            else
                # jump speed — teleport forward by speed patches
                steps = round(Int, car.speed)
                if steps > 0
                    old_x = car.x
                    car.x = mod1(car.x + steps, len)
                    road.occ[old_x, cur_row] = zero_entity
                    road.occ[car.x, cur_row] = eid
                end
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
