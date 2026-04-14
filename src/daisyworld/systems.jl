# --- Initialization ---

struct InitDaisyworldSystem <: System end

function initialize!(::InitDaisyworldSystem, world::World)
    params = get_resource(world, DaisyworldParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, TemperatureGrid)
    stats = get_resource(world, DaisyStats)
    stats.solar_luminosity = params.solar_luminosity
    w = grid.width

    total = w * w
    num_whites = round(Int, total * params.start_pct_whites / 100.0)
    num_blacks = round(Int, total * params.start_pct_blacks / 100.0)

    positions = [(x, y) for x in 1:w for y in 1:w]
    shuffle!(rng, positions)

    idx = 1
    for _ in 1:num_whites
        x, y = positions[idx]; idx += 1
        eid = new_entity!(world, (DaisyPosition(x, y), DaisyAge(rand(rng, 0:params.max_age)),
                                  Albedo(params.white_albedo), WhiteDaisy()))
        grid.occupant[x, y] = eid
    end
    for _ in 1:num_blacks
        x, y = positions[idx]; idx += 1
        eid = new_entity!(world, (DaisyPosition(x, y), DaisyAge(rand(rng, 0:params.max_age)),
                                  Albedo(params.black_albedo), BlackDaisy()))
        grid.occupant[x, y] = eid
    end

    # Initialize temperatures
    _calc_all_temps!(grid, stats, params)
    return nothing
end

# --- Temperature Calculation ---

struct CalcTemperatureSystem <: System end

function _local_heating(albedo::Float64, luminosity::Float64)
    absorbed = luminosity * (1.0 - albedo)
    absorbed <= 0.0 && return 80.0
    return 72.0 * log(absorbed) + 80.0
end

function _calc_all_temps!(grid::TemperatureGrid, stats::DaisyStats, params::DaisyworldParams)
    w = grid.width
    lum = stats.solar_luminosity

    for x in 1:w, y in 1:w
        eid = grid.occupant[x, y]
        if is_zero(eid)
            local_albedo = params.surface_albedo
        else
            # Get albedo from the entity - we store it in the grid temperature calc
            # For simplicity, we compute via the occupant tag
            local_albedo = params.surface_albedo  # will be overridden below
        end
        heating = _local_heating(local_albedo, lum)
        grid.temperature[x, y] = (grid.temperature[x, y] + heating) / 2.0
    end
end

function update!(::CalcTemperatureSystem, world::World)
    params = get_resource(world, DaisyworldParams)
    grid = get_resource(world, TemperatureGrid)
    stats = get_resource(world, DaisyStats)
    lum = stats.solar_luminosity
    w = grid.width

    # Calculate local temperatures with actual albedos
    for (_, positions, albedos) in Query(world, (DaisyPosition, Albedo))
        @inbounds for i in eachindex(positions)
            x, y = positions[i].x, positions[i].y
            heating = _local_heating(albedos[i].value, lum)
            grid.temperature[x, y] = (grid.temperature[x, y] + heating) / 2.0
        end
    end

    # Bare soil patches
    for x in 1:w, y in 1:w
        if is_zero(grid.occupant[x, y])
            heating = _local_heating(params.surface_albedo, lum)
            grid.temperature[x, y] = (grid.temperature[x, y] + heating) / 2.0
        end
    end
    return nothing
end

# --- Temperature Diffusion ---

struct DiffuseTemperatureSystem <: System end

function update!(::DiffuseTemperatureSystem, world::World)
    grid = get_resource(world, TemperatureGrid)
    w = grid.width
    temp = grid.temperature
    # 50% diffusion to neighbors
    buf = copy(temp)

    @inbounds for x in 1:w, y in 1:w
        share = temp[x, y] * 0.5 / 8.0
        buf[x, y] -= temp[x, y] * 0.5
        for dx in -1:1, dy in -1:1
            (dx == 0 && dy == 0) && continue
            nx = mod1(x + dx, w)
            ny = mod1(y + dy, w)
            buf[nx, ny] += share
        end
    end

    copyto!(temp, buf)
    return nothing
end

# --- Survivability (Aging + Reproduction) ---

struct SurvivabilitySystem <: System
    to_remove::Vector{Entity}
    to_spawn::Vector{Tuple{Int, Int, Bool}}  # (x, y, is_white)
end
SurvivabilitySystem() = SurvivabilitySystem(Entity[], Tuple{Int,Int,Bool}[])

function update!(system::SurvivabilitySystem, world::World)
    params = get_resource(world, DaisyworldParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, TemperatureGrid)
    w = grid.width

    empty!(system.to_remove)
    empty!(system.to_spawn)

    for (eids, positions, ages, albedos) in Query(world, (DaisyPosition, DaisyAge, Albedo))
        @inbounds for i in eachindex(positions)
            ages[i].age += 1
            if ages[i].age > params.max_age
                push!(system.to_remove, eids[i])
                continue
            end

            # Reproduction: fitness based on local temperature
            x, y = positions[i].x, positions[i].y
            temp = grid.temperature[x, y]
            # Parabolic fitness: seed_threshold = 0.1457 * T - 0.0032 * T^2 - 0.6443
            seed_threshold = 0.1457 * temp - 0.0032 * temp^2 - 0.6443
            if seed_threshold > 0.0 && rand(rng) < seed_threshold
                # Find empty neighbor
                neighbors = Tuple{Int,Int}[]
                for dx in -1:1, dy in -1:1
                    (dx == 0 && dy == 0) && continue
                    nx = mod1(x + dx, w)
                    ny = mod1(y + dy, w)
                    is_zero(grid.occupant[nx, ny]) && push!(neighbors, (nx, ny))
                end
                if !isempty(neighbors)
                    nx, ny = neighbors[rand(rng, 1:length(neighbors))]
                    is_white = albedos[i].value > 0.5
                    push!(system.to_spawn, (nx, ny, is_white))
                end
            end
        end
    end

    # Remove dead daisies
    for e in system.to_remove
        if is_alive(world, e)
            pos = get_components(world, e, (DaisyPosition,))[1]
            grid.occupant[pos.x, pos.y] = zero_entity
            remove_entity!(world, e)
        end
    end

    # Spawn new daisies
    for (x, y, is_white) in system.to_spawn
        !is_zero(grid.occupant[x, y]) && continue  # cell taken by another spawn
        if is_white
            eid = new_entity!(world, (DaisyPosition(x, y), DaisyAge(0),
                                      Albedo(params.white_albedo), WhiteDaisy()))
        else
            eid = new_entity!(world, (DaisyPosition(x, y), DaisyAge(0),
                                      Albedo(params.black_albedo), BlackDaisy()))
        end
        grid.occupant[x, y] = eid
    end
    return nothing
end

# --- Statistics ---

struct DaisyStatsSystem <: System end

function update!(::DaisyStatsSystem, world::World)
    grid = get_resource(world, TemperatureGrid)
    stats = get_resource(world, DaisyStats)
    params = get_resource(world, DaisyworldParams)

    stats.global_temperature = mean(grid.temperature)

    whites = 0
    blacks = 0
    for (eids, _) in Query(world, (DaisyPosition,); with=(WhiteDaisy,))
        whites += length(eids)
    end
    for (eids, _) in Query(world, (DaisyPosition,); with=(BlackDaisy,))
        blacks += length(eids)
    end
    stats.num_whites = whites
    stats.num_blacks = blacks

    # Ramp scenario
    if params.ramp_scenario
        tick = get_resource(world, Tick).tick
        stats.solar_luminosity = 0.2 + (3.0 - 0.2) * tick / params.max_ticks
    end
    return nothing
end

# --- Termination ---

struct DaisyworldTerminationSystem <: System end

function update!(::DaisyworldTerminationSystem, world::World)
    params = get_resource(world, DaisyworldParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
