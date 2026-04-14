# --- Initialization ---

struct InitSleuthSystem <: System end

function initialize!(::InitSleuthSystem, world::World)
    params = get_resource(world, SleuthParams)
    grid = get_resource(world, SleuthGrid)
    stats = get_resource(world, SleuthStats)
    w, h = grid.width, grid.height

    # Load 4 raster layers
    urban_r = gis_load_asc(joinpath(params.data_dir, "urbandclr3.asc"))
    county_r = gis_load_asc(joinpath(params.data_dir, "countyls.asc"))
    excluded_r = gis_load_asc(joinpath(params.data_dir, "excludedlr.asc"))
    road_r = gis_load_asc(joinpath(params.data_dir, "rasterroad.asc"))

    # Use common envelope and resample to model grid size
    env = gis_envelope(urban_r)
    half_w = div(w, 2)
    half_h = div(h, 2)
    transform = gis_set_world_envelope(env, -half_w, half_w, -half_h, half_h)

    grid.urban = gis_apply_raster(urban_r, w, h, transform)
    grid.county = gis_apply_raster(county_r, w, h, transform)
    grid.excluded = gis_apply_raster(excluded_r, w, h, transform)
    grid.road = gis_apply_raster(road_r, w, h, transform)

    nodata = urban_r.nodata

    # Calculate centroid of county 43
    cx43, cy43, n43 = 0.0, 0.0, 0
    for x in 1:w, y in 1:h
        cval = grid.county[x, y]
        if cval != nodata && round(Int, cval) == 43
            cx43 += x; cy43 += y; n43 += 1
        end
    end
    if n43 > 0
        cx43 /= n43; cy43 /= n43
    else
        cx43 = w / 2.0; cy43 = h / 2.0
    end

    # Calculate capdist and determine availability, county counts
    for cid in SLEUTH_COUNTY_IDS
        grid.county_urban[cid] = 0
        grid.county_total[cid] = 0
    end

    for x in 1:w, y in 1:h
        grid.capdist[x, y] = sqrt((x - cx43)^2 + (y - cy43)^2)
        cval = grid.county[x, y]
        cid = (cval == nodata || cval < 0) ? 0 : round(Int, cval)
        # Urban raster: 2 = urbanized, 1 = rural, -9999 = nodata
        uval = grid.urban[x, y]
        is_urban = uval != nodata && uval >= 2.0
        # Excluded raster: 1 = excluded, -9999 = nodata
        eval_v = grid.excluded[x, y]
        is_excluded = eval_v != nodata && eval_v >= 1.0
        in_valid_county = cid > 0 && cid < 57

        grid.available[x, y] = in_valid_county && !is_excluded && !is_urban

        if in_valid_county && cid in SLEUTH_COUNTY_IDS
            grid.county_total[cid] = get(grid.county_total, cid, 0) + 1
            if is_urban
                grid.county_urban[cid] = get(grid.county_urban, cid, 0) + 1
            end
        end
    end

    _update_sleuth_stats!(grid, stats)
    return nothing
end

function _update_sleuth_stats!(grid::SleuthGrid, stats::SleuthStats)
    w, h = grid.width, grid.height
    total_urban = 0
    total_patches = 0
    nodata = -9999.0

    # Recount county urban/total
    for cid in SLEUTH_COUNTY_IDS
        grid.county_urban[cid] = 0
        grid.county_total[cid] = 0
    end

    for x in 1:w, y in 1:h
        cval = grid.county[x, y]
        cid = (cval == nodata || cval < 0) ? 0 : round(Int, cval)
        if cid > 0 && cid < 57
            total_patches += 1
            uval = grid.urban[x, y]
            is_urban = uval != nodata && uval >= 2.0
            if is_urban
                total_urban += 1
            end
            if cid in SLEUTH_COUNTY_IDS
                grid.county_total[cid] = get(grid.county_total, cid, 0) + 1
                if is_urban
                    grid.county_urban[cid] = get(grid.county_urban, cid, 0) + 1
                end
            end
        end
    end

    stats.urbantotal = total_urban
    stats.purbantotal = total_patches > 0 ? total_urban / total_patches : 0.0

    # Herfindahl concentration index
    hhi = 0.0
    for cid in SLEUTH_COUNTY_IDS
        cu = get(grid.county_urban, cid, 0)
        if total_urban > 0
            share = cu / total_urban
            hhi += share^2
        end
    end
    stats.concentration = hhi
    return nothing
end

function _get_tax(grid::SleuthGrid, x::Int, y::Int, lobby::Float64)
    cval = grid.county[x, y]
    cid = (cval == -9999.0 || cval < 0) ? 0 : round(Int, cval)
    cu = get(grid.county_urban, cid, 0)
    ct = get(grid.county_total, cid, 0)
    pct_urban = ct > 0 ? cu / ct : 0.0
    return pct_urban * lobby * 100.0
end

# Wrapping helper
function _wrap(v::Int, lo::Int, hi::Int)
    r = hi - lo + 1
    return mod(v - lo, r) + lo
end

# --- Growth System ---

struct SleuthGrowthSystem <: System end

function update!(::SleuthGrowthSystem, world::World)
    params = get_resource(world, SleuthParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, SleuthGrid)
    w, h = grid.width, grid.height

    # Spontaneous growth
    for _ in 1:params.rounds
        x = rand(rng, 1:w)
        y = rand(rng, 1:h)
        if !grid.available[x, y]
            continue
        end
        tax = _get_tax(grid, x, y, params.lobby)
        threshold = params.dispersion * 5.3 * (100.0 - tax) / 100.0
        if rand(rng) * 100.0 < threshold
            # Urbanize
            grid.urban[x, y] = 2.0
            grid.available[x, y] = false

            # Spread to up to 2 neighbors
            spread_count = 0
            for _ in 1:8
                spread_count >= 2 && break
                dx = rand(rng, -1:1)
                dy = rand(rng, -1:1)
                (dx == 0 && dy == 0) && continue
                nx = _wrap(x + dx, 1, w)
                ny = _wrap(y + dy, 1, h)
                if grid.available[nx, ny]
                    ntax = _get_tax(grid, nx, ny, params.lobby)
                    if rand(rng) * 100.0 < params.newspread * (100.0 - ntax) / 100.0
                        grid.urban[nx, ny] = 2.0
                        grid.available[nx, ny] = false
                        spread_count += 1
                    end
                end
            end
        end
    end

    # Edge growth: available patches with >= 3 urban neighbors urbanize
    to_urbanize = Tuple{Int,Int}[]
    for x in 1:w, y in 1:h
        if !grid.available[x, y]
            continue
        end
        urban_neighbors = 0
        for dx in -1:1, dy in -1:1
            (dx == 0 && dy == 0) && continue
            nx = _wrap(x + dx, 1, w)
            ny = _wrap(y + dy, 1, h)
            if grid.urban[nx, ny] >= 2.0
                urban_neighbors += 1
            end
        end
        if urban_neighbors >= 3
            tax = _get_tax(grid, x, y, params.lobby)
            if rand(rng) * 100.0 < params.spread * (100.0 - tax) / 100.0
                push!(to_urbanize, (x, y))
            end
        end
    end
    for (x, y) in to_urbanize
        grid.urban[x, y] = 2.0
        grid.available[x, y] = false
    end

    return nothing
end

# --- Stats Update ---

struct SleuthStatsSystem <: System end

function update!(::SleuthStatsSystem, world::World)
    grid = get_resource(world, SleuthGrid)
    stats = get_resource(world, SleuthStats)
    _update_sleuth_stats!(grid, stats)
    return nothing
end

# --- Termination ---

struct SleuthTerminationSystem <: System end

function update!(::SleuthTerminationSystem, world::World)
    params = get_resource(world, SleuthParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
