# Traffic Basic systems matching NetLogo Traffic Basic
# Execution order: init → go (accelerate/decelerate + move) → terminate

using Random: shuffle!

# --- Initialization ---
# NetLogo: crt number-of-cars with random positions, separated so no two share a patch

struct InitTBSystem <: System end

function initialize!(::InitTBSystem, world::World)
    params = get_resource(world, TBParams)
    rng = get_resource(world, RNGResource).rng
    road = get_resource(world, TBRoad)

    n = min(params.number_of_cars, params.road_length)
    empty!(road.cars)

    # Pick n distinct integer positions (NetLogo separate-cars ensures no overlap)
    positions = shuffle!(rng, collect(0:params.road_length - 1))[1:n]

    for pos in positions
        spd = 0.1 + rand(rng) * 0.9
        push!(road.cars, TBCar(Float64(pos), spd, 1.0, 0.0))
    end

    # Update stats
    stats = get_resource(world, TBStats)
    stats.mean_speed = sum(c.speed for c in road.cars) / length(road.cars)
    return nothing
end

# --- Go (main step) ---
# NetLogo: ask turtles (shuffled) — find car-ahead, adjust speed, move

struct TBGoSystem <: System end

function update!(::TBGoSystem, world::World)
    params = get_resource(world, TBParams)
    rng = get_resource(world, RNGResource).rng
    road = get_resource(world, TBRoad)
    stats = get_resource(world, TBStats)
    L = road.length
    cars = road.cars

    n = length(cars)
    n == 0 && return nothing

    # NetLogo `ask turtles` shuffles — process in random order
    order = shuffle!(rng, collect(1:n))

    for idx in order
        car = cars[idx]
        # patch-ahead 1: the patch at floor(x) + 1, wrapped
        patch_ahead = mod(floor(Int, car.x) + 1, L)

        # Find car-ahead: any OTHER car whose floor(x) == patch_ahead
        car_ahead_speed = nothing
        for j in 1:n
            j == idx && continue
            if mod(floor(Int, cars[j].x), L) == patch_ahead
                car_ahead_speed = cars[j].speed
                break
            end
        end

        if car_ahead_speed !== nothing
            # Match speed of car ahead, then decelerate
            car.speed = car_ahead_speed
            car.speed -= params.deceleration
        else
            # No car ahead — accelerate
            car.speed += params.acceleration
        end

        # Clamp speed to [speed_min, speed_limit]
        car.speed < car.speed_min && (car.speed = car.speed_min)
        car.speed > car.speed_limit && (car.speed = car.speed_limit)

        # Move forward with wrapping
        car.x = mod(car.x + car.speed, L)
    end

    # Update mean speed
    stats.mean_speed = sum(c.speed for c in cars) / n
    return nothing
end

# --- Termination ---

struct TBTerminationSystem <: System end

function update!(::TBTerminationSystem, world::World)
    params = get_resource(world, TBParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
