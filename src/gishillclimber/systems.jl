# GIS Hill Climber systems
# Order: init → move → stats → termination

# --- Initialization ---
struct InitGHCSystem <: System end

function initialize!(::InitGHCSystem, world::World)
    params = get_resource(world, GHCParams)
    rng    = get_resource(world, RNGResource).rng
    grid   = get_resource(world, GHCGrid)
    n      = params.grid_size

    # Create synthetic Gaussian elevation raster
    env = GisEnvelope(-25.0, 25.0, -25.0, 25.0)
    raster = gis_create_raster(n, n, env)
    cs = 50.0 / n
    for row in 0:(n-1), col in 0:(n-1)
        x = -25.0 + (col + 0.5) * cs
        y =  25.0 - (row + 0.5) * cs
        z1 = 100.0 * exp(-(x^2 + y^2) / 128.0)
        z2 =  80.0 * exp(-((x - 12)^2 + (y + 10)^2) / 50.0)
        z3 =  60.0 * exp(-((x + 15)^2 + (y - 8)^2) / 72.0)
        gis_set_raster_value!(raster, col, row, z1 + z2 + z3)
    end

    grid.elev = gis_apply_raster_simple(raster)

    # Sobel gradient computation
    sx_raster = gis_convolve(raster, SOBEL_X)
    sy_raster = gis_convolve(raster, SOBEL_Y)
    grid.slope_x = gis_apply_raster_simple(sx_raster)
    grid.slope_y = gis_apply_raster_simple(sy_raster)

    # Spawn turtles at random grid positions
    for _ in 1:params.n_turtles
        x = rand(rng, 1:n)
        y = rand(rng, 1:n)
        new_entity!(world, (GHCPosition(x, y), GHCTag()))
    end

    return nothing
end

# --- Movement: climb to highest Moore neighbor (wrapping) ---
struct GHCMoveSystem <: System end

function update!(::GHCMoveSystem, world::World)
    grid = get_resource(world, GHCGrid)
    n = grid.width

    for (_, positions, _) in Query(world, (GHCPosition, GHCTag))
        @inbounds for i in eachindex(positions)
            pos = positions[i]
            best_elev = grid.elev[pos.x, pos.y]
            best_x, best_y = pos.x, pos.y

            for dx in -1:1, dy in -1:1
                (dx == 0 && dy == 0) && continue
                nx = mod1(pos.x + dx, n)
                ny = mod1(pos.y + dy, n)
                e = grid.elev[nx, ny]
                if e > best_elev
                    best_elev = e
                    best_x = nx
                    best_y = ny
                end
            end

            pos.x = best_x
            pos.y = best_y
        end
    end
    return nothing
end

# --- Statistics ---
struct GHCStatsSystem <: System end

function update!(::GHCStatsSystem, world::World)
    grid  = get_resource(world, GHCGrid)
    stats = get_resource(world, GHCStats)

    total_elev = 0.0
    count      = 0
    n_peak     = 0

    for (_, positions, _) in Query(world, (GHCPosition, GHCTag))
        @inbounds for i in eachindex(positions)
            pos = positions[i]
            e = grid.elev[pos.x, pos.y]
            total_elev += e
            count += 1
            if e > 90.0
                n_peak += 1
            end
        end
    end

    stats.mean_elevation = count > 0 ? total_elev / count : 0.0
    stats.n_at_peak = n_peak
    return nothing
end

# --- Termination ---
struct GHCTerminationSystem <: System end

function update!(::GHCTerminationSystem, world::World)
    params = get_resource(world, GHCParams)
    tick   = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
