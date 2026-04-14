# --- Initialization ---

struct InitTGSystem <: System end

# Check if (x,y) is a road patch using NetLogo's formula:
# Vertical roads: floor((pxcor + max-pxcor - floor(grid-x-inc - 1)) mod grid-x-inc) == 0
# Horizontal roads: floor((pycor + max-pycor) mod grid-y-inc) == 0
# Here x,y are 1-indexed; NetLogo pxcor = x - (w+1)/2, max-pxcor = (w-1)/2
function _tg_is_x_road(x::Int, w::Int, gxi::Float64)
    pxcor = x - (w + 1) ÷ 2
    max_pxcor = (w - 1) ÷ 2
    return floor((pxcor + max_pxcor - floor(gxi - 1)) % gxi) == 0
end

function _tg_is_y_road(y::Int, h::Int, gyi::Float64)
    pycor = y - (h + 1) ÷ 2
    max_pycor = (h - 1) ÷ 2
    return floor((pycor + max_pycor) % gyi) == 0
end

function initialize!(::InitTGSystem, world::World)
    params = get_resource(world, TGParams)
    rng = get_resource(world, RNGResource).rng
    road = get_resource(world, TGRoad)
    w, h = road.width, road.height
    gxi, gyi = road.grid_x_inc, road.grid_y_inc

    # Setup roads and intersections
    road_patches = Tuple{Int,Int}[]
    for x in 1:w, y in 1:h
        is_xr = _tg_is_x_road(x, w, gxi)
        is_yr = _tg_is_y_road(y, h, gyi)
        is_r = is_xr || is_yr
        road.is_road[x, y] = is_r
        if is_r
            road.patch_color[x, y] = 3  # white (road)
            push!(road_patches, (x, y))
        end
        if is_xr && is_yr
            road.is_intersection[x, y] = true
            road.green_light_up[x, y] = true
            road.my_phase[x, y] = 0
        end
    end

    # Setup signal colors
    _tg_set_signal_colors!(road, params)

    # Place cars on road patches
    Random.shuffle!(rng, road_patches)
    n_cars = min(params.num_cars, length(road_patches))

    for i in 1:n_cars
        rx, ry = road_patches[i]
        # Determine direction based on position (vertical road = up-car)
        is_xr = _tg_is_x_road(rx, w, gxi)
        up_car = if road.is_intersection[rx, ry]
            rand(rng, Bool)
        else
            is_xr  # on vertical road → heading south (up-car)
        end
        speed = 0.0
        new_entity!(world, (TGCar(Float64(rx), Float64(ry), speed, up_car, 0),))
    end
    return nothing
end

function _tg_set_signal_colors!(road::TGRoad, params::TGParams)
    w, h = road.width, road.height
    # Reset all road patches to white first
    for x in 1:w, y in 1:h
        if road.is_road[x, y]
            road.patch_color[x, y] = 3  # white
        end
    end
    # Set signal patches at each intersection
    for x in 1:w, y in 1:h
        if road.is_intersection[x, y]
            if params.power
                if road.green_light_up[x, y]
                    # patch-at -1 0 = red (east-west gets red)
                    if x - 1 >= 1; road.patch_color[x - 1, y] = 1; end  # red
                    # patch-at 0 1 = green (north-south gets green)
                    if y + 1 <= h; road.patch_color[x, y + 1] = 2; end  # green
                else
                    if x - 1 >= 1; road.patch_color[x - 1, y] = 2; end  # green
                    if y + 1 <= h; road.patch_color[x, y + 1] = 1; end  # red
                end
            else
                if x - 1 >= 1; road.patch_color[x - 1, y] = 3; end
                if y + 1 <= h; road.patch_color[x, y + 1] = 3; end
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
    accel = 0.099

    # ── Set signals ──
    # NetLogo: phase increments each tick, resets at ticks_per_cycle
    phase = tick_val % params.ticks_per_cycle
    for x in 1:w, y in 1:h
        if road.is_intersection[x, y] && road.my_phase[x, y] >= 0
            mp = road.my_phase[x, y]
            if phase == (mp * params.ticks_per_cycle) ÷ 100
                road.green_light_up[x, y] = !road.green_light_up[x, y]
            end
        end
    end
    _tg_set_signal_colors!(road, params)

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

    # Build spatial index: patch → list of (entity, up_car?) for turtles-at checks
    car_at = Dict{Tuple{Int,Int}, Vector{Tuple{Entity, Bool, Float64}}}()
    for (eid, _) in cars
        car = get_components(world, eid, (TGCar,))[1]
        px = _tg_patch(car.x, w)
        py = _tg_patch(car.y, h)
        key = (px, py)
        entry = (eid, car.up_car, car.speed)
        if haskey(car_at, key)
            push!(car_at[key], entry)
        else
            car_at[key] = [entry]
        end
    end

    for (eid, _) in cars
        car = get_components(world, eid, (TGCar,))[1]
        n_cars += 1
        px = _tg_patch(car.x, w)
        py = _tg_patch(car.y, h)

        # ── set-car-speed: check pcolor at current patch ──
        if road.patch_color[px, py] == 1  # red
            car.speed = 0.0
        else
            # Check car ahead
            if car.up_car
                dx, dy = 0, -1  # heading 180 = south
            else
                dx, dy = 1, 0   # heading 90 = east
            end
            ax = mod1(px + dx, w)
            ay = mod1(py + dy, h)
            ahead_list = get(car_at, (ax, ay), Tuple{Entity, Bool, Float64}[])
            ahead = filter(e -> e[1] != eid, ahead_list)
            if !isempty(ahead)
                # Check if any have different direction
                cross = filter(e -> e[2] != car.up_car, ahead)
                if !isempty(cross)
                    car.speed = 0.0
                else
                    # Same direction: match speed and decelerate
                    ahead_speed = ahead[rand(rng, 1:length(ahead))][3]
                    car.speed = ahead_speed
                    car.speed = car.speed <= 0 ? 0.0 : car.speed - accel
                end
            else
                # No car ahead: accelerate
                car.speed = car.speed > params.speed_limit ? params.speed_limit : car.speed + accel
            end
        end

        # ── Move: fd speed ──
        old_px, old_py = px, py
        if car.up_car
            car.y = _tg_wrap(car.y - car.speed, h)
        else
            car.x = _tg_wrap(car.x + car.speed, w)
        end
        new_px = _tg_patch(car.x, w)
        new_py = _tg_patch(car.y, h)

        # Update spatial index
        if new_px != old_px || new_py != old_py
            old_key = (old_px, old_py)
            if haskey(car_at, old_key)
                filter!(e -> e[1] != eid, car_at[old_key])
            end
            new_key = (new_px, new_py)
            entry = (eid, car.up_car, car.speed)
            if haskey(car_at, new_key)
                push!(car_at[new_key], entry)
            else
                car_at[new_key] = [entry]
            end
        else
            # Update speed in spatial index
            old_key = (old_px, old_py)
            if haskey(car_at, old_key)
                for j in eachindex(car_at[old_key])
                    if car_at[old_key][j][1] == eid
                        car_at[old_key][j] = (eid, car.up_car, car.speed)
                        break
                    end
                end
            end
        end

        # ── Record data ──
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

# Get 1-indexed patch coordinate from float position in wrapping world of size sz
function _tg_patch(pos::Float64, sz::Int)
    # NetLogo: pxcor = round(xcor), and patches are 1..sz in our system
    p = round(Int, pos)
    return mod1(p, sz)
end

# Wrap a float position into [1, sz+1) range
function _tg_wrap(pos::Float64, sz::Int)
    p = mod(pos - 1.0, Float64(sz)) + 1.0
    return p
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
