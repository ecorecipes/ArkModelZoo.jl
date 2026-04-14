# --- Helpers ---

function _climate_can_move(x::Float64, y::Float64, heading::Float64, dist::Float64, w::Int, h::Int)
    θ = deg2rad(heading)
    nx = x + sin(θ) * dist
    ny = y + cos(θ) * dist
    px = round(Int, nx)
    py = round(Int, ny)
    return 1 <= px <= w && 1 <= py <= h
end

function _climate_forward!(p::ClimateParticle, dist::Float64)
    θ = deg2rad(p.heading)
    p.x += sin(θ) * dist
    p.y += cos(θ) * dist
end

function _climate_is_blue(y::Float64, earth_top_y::Int)
    return round(Int, y) > earth_top_y
end

# --- Initialization ---

struct InitClimateChangeSystem <: System end

function initialize!(::InitClimateChangeSystem, world::World)
    params = get_resource(world, ClimateChangeParams)
    rng = get_resource(world, RNGResource).rng

    # Optionally create CO2 molecules in the atmosphere
    for _ in 1:params.num_CO2
        x = Float64(rand(rng, 1:params.grid_width))
        y = Float64(rand(rng, (params.earth_top_y + 1):params.sky_top_y))
        heading = rand(rng) * 360.0
        new_entity!(world, (ClimateParticle(BREED_CO2, x, y, heading),))
    end
    return nothing
end

# --- Sunshine ---

struct RunSunshineSystem <: System end

function update!(::RunSunshineSystem, world::World)
    params = get_resource(world, ClimateChangeParams)
    rng = get_resource(world, RNGResource).rng
    w, h = params.grid_width, params.grid_height
    earth_top_y = params.earth_top_y

    # Move existing rays; die if can't move
    to_remove = Entity[]
    to_convert = Entity[]  # rays that hit earth
    for (eids, particles) in Query(world, (ClimateParticle,))
        @inbounds for i in eachindex(eids)
            p = particles[i]
            p.breed == BREED_RAY || continue
            if !_climate_can_move(p.x, p.y, p.heading, 0.3, w, h)
                push!(to_remove, eids[i])
            else
                _climate_forward!(p, 0.3)
                if p.y <= Float64(earth_top_y)
                    push!(to_convert, eids[i])
                end
            end
        end
    end

    for eid in to_remove
        remove_entity!(world, eid)
    end

    # Encounter earth: reflect (albedo) or absorb (become heat)
    for eid in to_convert
        p = get_components(world, eid, (ClimateParticle,))[1]
        if rand(rng, 0:99) < round(Int, 100 * params.albedo)
            p.heading = 180.0 - p.heading
        else
            p.heading += Float64(rand(rng, 0:44) - rand(rng, 0:44))
            p.breed = BREED_HEAT
        end
    end

    # Create new sunshine
    if 10.0 * params.sun_brightness > rand(rng, 0:49)
        # NetLogo: setxy (random 10) + min-pxcor max-pycor
        # min-pxcor=-24 → 1-based x = random(10)+1, y = max_y
        x = Float64(rand(rng, 0:9) + 1)
        y = Float64(h)
        new_entity!(world, (ClimateParticle(BREED_RAY, x, y, 160.0),))
    end
    return nothing
end

# --- Heat ---

struct RunHeatSystem <: System end

function update!(::RunHeatSystem, world::World)
    params = get_resource(world, ClimateChangeParams)
    rng = get_resource(world, RNGResource).rng
    stats = get_resource(world, ClimateStats)
    w, h = params.grid_width, params.grid_height
    earth_top_y = params.earth_top_y

    # Count heats for temperature update
    n_heats = 0
    for (_, particles) in Query(world, (ClimateParticle,))
        @inbounds for i in eachindex(particles)
            if particles[i].breed == BREED_HEAT
                n_heats += 1
            end
        end
    end
    stats.temperature = 0.99 * stats.temperature + 0.01 * (12.0 + 0.1 * n_heats)

    # Process each heat
    heat_list = Entity[]
    for (eids, particles) in Query(world, (ClimateParticle,))
        @inbounds for i in eachindex(eids)
            if particles[i].breed == BREED_HEAT
                push!(heat_list, eids[i])
            end
        end
    end
    Random.shuffle!(rng, heat_list)

    for eid in heat_list
        p = get_components(world, eid, (ClimateParticle,))[1]
        dist = 0.5 * rand(rng)
        if _climate_can_move(p.x, p.y, p.heading, dist, w, h)
            _climate_forward!(p, dist)
        else
            p.heading = 180.0 - p.heading
        end
        if p.y >= Float64(earth_top_y)
            # pxcor = x - 25; condition: pxcor > 0 and pxcor < max_pxcor - 8 = 16
            pxcor = p.x - 25.0
            if stats.temperature > 20.0 + rand(rng, 0:39) && pxcor > 0.0 && pxcor < 16.0
                p.breed = BREED_IR
                p.heading = 20.0
            else
                p.heading = Float64(100 + rand(rng, 0:159))
            end
        end
    end
    return nothing
end

# --- IR ---

struct RunIRSystem <: System end

function update!(::RunIRSystem, world::World)
    params = get_resource(world, ClimateChangeParams)
    rng = get_resource(world, RNGResource).rng
    w, h = params.grid_width, params.grid_height
    earth_top_y = params.earth_top_y

    ir_list = Entity[]
    for (eids, particles) in Query(world, (ClimateParticle,))
        @inbounds for i in eachindex(eids)
            if particles[i].breed == BREED_IR
                push!(ir_list, eids[i])
            end
        end
    end
    Random.shuffle!(rng, ir_list)

    to_remove = Entity[]
    for eid in ir_list
        p = get_components(world, eid, (ClimateParticle,))[1]
        if !_climate_can_move(p.x, p.y, p.heading, 0.3, w, h)
            push!(to_remove, eid)
            continue
        end
        _climate_forward!(p, 0.3)

        if p.y <= Float64(earth_top_y)
            p.breed = BREED_HEAT
            p.heading += Float64(rand(rng, 0:44) - rand(rng, 0:44))
        end

        # Check for CO2 on same patch
        my_px = round(Int, p.x)
        my_py = round(Int, p.y)
        co2_here = false
        for (_, particles2) in Query(world, (ClimateParticle,))
            @inbounds for j in eachindex(particles2)
                q = particles2[j]
                if q.breed == BREED_CO2 && round(Int, q.x) == my_px && round(Int, q.y) == my_py
                    co2_here = true
                    break
                end
            end
            co2_here && break
        end
        if co2_here
            p.heading = 180.0 - p.heading
        end
    end

    for eid in to_remove
        remove_entity!(world, eid)
    end
    return nothing
end

# --- CO2 ---

struct RunCO2System <: System end

function update!(::RunCO2System, world::World)
    params = get_resource(world, ClimateChangeParams)
    rng = get_resource(world, RNGResource).rng
    w, h = params.grid_width, params.grid_height
    earth_top_y = params.earth_top_y

    co2_list = Entity[]
    for (eids, particles) in Query(world, (ClimateParticle,))
        @inbounds for i in eachindex(eids)
            if particles[i].breed == BREED_CO2
                push!(co2_list, eids[i])
            end
        end
    end
    Random.shuffle!(rng, co2_list)

    for eid in co2_list
        p = get_components(world, eid, (ClimateParticle,))[1]
        p.heading += Float64(rand(rng, 0:50) - 25)
        dist = 0.05 + rand(rng) * 0.1
        # Bounce off non-blue patches (earth and underground)
        if !_climate_is_blue(p.y + cos(deg2rad(p.heading)) * dist, earth_top_y)
            p.heading = 180.0 - p.heading
        end
        if _climate_can_move(p.x, p.y, p.heading, dist, w, h)
            _climate_forward!(p, dist)
        end
    end
    return nothing
end

# --- Termination ---

struct ClimateChangeTerminationSystem <: System end

function update!(::ClimateChangeTerminationSystem, world::World)
    params = get_resource(world, ClimateChangeParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
