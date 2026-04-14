# --- Initialization ---

struct InitRadSystem <: System end

function initialize!(::InitRadSystem, world::World)
    params = get_resource(world, RadParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, RadGrid)
    state = get_resource(world, RadState)
    w, h = grid.width, grid.height

    # Load 4 raster layers
    dem_r = gis_load_asc(joinpath(params.data_dir, "KIMB_DEM_1.asc"))
    tslb_r = gis_load_asc(joinpath(params.data_dir, "KIMB_YSLB_2.asc"))
    veg_r = gis_load_asc(joinpath(params.data_dir, "KIMB_VEG_1.asc"))
    wet_r = gis_load_asc(joinpath(params.data_dir, "KIMB_WET_2.asc"))

    grid.elevation = gis_apply_raster_simple(dem_r)
    grid.tslb = gis_apply_raster_simple(tslb_r)
    grid.radical_spread_value = gis_apply_raster_simple(veg_r)
    grid.wetness = gis_apply_raster_simple(wet_r)

    # Resize grids to match actual loaded dimensions
    w = size(grid.elevation, 1)
    h = size(grid.elevation, 2)
    grid.width = w
    grid.height = h

    # Ensure auxiliary grids match loaded dimensions
    if size(grid.slope) != (w, h)
        grid.slope = ones(Float64, w, h)
        grid.cell = ones(Float64, w, h)
        grid.radicalism_spread_area = fill(100.0, w, h)
        grid.radicalism_spread_area_time = ones(Float64, w, h)
        grid.spread_ability = zeros(Float64, w, h)
        grid.radicalized = falses(w, h)
    end

    # tslb += 1
    for x in 1:w, y in 1:h
        grid.tslb[x, y] += 1.0
    end

    # Create townships at random interior positions
    margin = 10
    for _ in 1:params.num_townships
        tx = rand(rng, margin:(w-margin))
        ty = rand(rng, margin:(h-margin))
        push!(state.townships, RadTownship(tx, ty, false))
    end

    # Create terrorist clusters at random interior positions
    state.network = NwGraph(params.num_terrorist_clusters)
    for i in 1:params.num_terrorist_clusters
        cx = rand(rng, margin:(w-margin))
        cy = rand(rng, margin:(h-margin))
        push!(state.terrorist_clusters, RadTerroristCluster(cx, cy, params.radicalism_init, true))
        # Radicalize the initial patch
        grid.radicalized[cx, cy] = true
    end

    # Build initial network: connect clusters within link_distance
    for i in 1:params.num_terrorist_clusters
        for j in (i+1):params.num_terrorist_clusters
            ci = state.terrorist_clusters[i]
            cj = state.terrorist_clusters[j]
            dist = sqrt(Float64((ci.x - cj.x)^2 + (ci.y - cj.y)^2))
            if dist <= params.link_distance && nw_degree(state.network, i) < params.degree && nw_degree(state.network, j) < params.degree
                nw_add_edge!(state.network, i, j)
            end
        end
    end

    _calc_spread_ability!(grid, params)
    _update_rad_stats!(grid, state, world)
    return nothing
end

function _calc_spread_ability!(grid::RadGrid, params::RadParams)
    w, h = grid.width, grid.height
    ln27 = log(2.7)
    ln18 = log(1.8)
    log4 = log(4.0)

    for x in 1:w, y in 1:h
        tslb_val = max(grid.tslb[x, y], 0.0)
        rsv = grid.radical_spread_value[x, y]
        sa = (log(tslb_val + 1.0) / ln27) * (rsv + 1.0) * ((log4 / ln18) + 1.0) / params.growth
        grid.spread_ability[x, y] = sa
    end
    return nothing
end

# Wrapping helper
function _rad_wrap(v::Int, sz::Int)
    return mod1(v, sz)
end

function _calc_slope!(grid::RadGrid)
    w, h = grid.width, grid.height
    for x in 1:w, y in 1:h
        e = grid.elevation[x, y]
        max_diff = 0.0
        for dx in -1:1, dy in -1:1
            (dx == 0 && dy == 0) && continue
            nx = _rad_wrap(x + dx, w)
            ny = _rad_wrap(y + dy, h)
            diff = abs(grid.elevation[nx, ny] - e)
            if diff > max_diff
                max_diff = diff
            end
        end
        grid.slope[x, y] = max(max_diff / 100.0, 0.01)
    end
    return nothing
end

function _update_rad_stats!(grid::RadGrid, state::RadState, world::World)
    stats = get_resource(world, RadStats)
    w, h = grid.width, grid.height
    total = w * h
    rad_count = 0
    total_rad = 0.0

    for x in 1:w, y in 1:h
        if grid.radicalized[x, y]
            rad_count += 1
            total_rad += grid.spread_ability[x, y]
        end
    end

    stats.percent_radicals = total > 0 ? 100.0 * rad_count / total : 0.0
    stats.total_radicalism = total_rad

    n_town = length(state.townships)
    n_over = count(t -> t.overtaken, state.townships)
    stats.overtaken_townships = n_town > 0 ? 100.0 * n_over / n_town : 0.0
    return nothing
end

# --- Slope Calculation ---

struct RadSlopeSystem <: System end

function update!(::RadSlopeSystem, world::World)
    grid = get_resource(world, RadGrid)
    _calc_slope!(grid)
    return nothing
end

# --- Radicalism Spread ---

struct RadSpreadSystem <: System end

function update!(::RadSpreadSystem, world::World)
    params = get_resource(world, RadParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, RadGrid)
    w, h = grid.width, grid.height

    new_rad = falses(w, h)
    for x in 1:w, y in 1:h
        new_rad[x, y] = grid.radicalized[x, y]
    end

    for x in 1:w, y in 1:h
        !grid.radicalized[x, y] && continue
        # Spread to neighbors
        for dx in -1:1, dy in -1:1
            (dx == 0 && dy == 0) && continue
            nx = _rad_wrap(x + dx, w)
            ny = _rad_wrap(y + dy, h)
            if !new_rad[nx, ny]
                sa = grid.spread_ability[x, y]
                sl = grid.slope[x, y]
                threshold = sa * grid.cell[x, y] + sl * 0.5
                if rand(rng, 0:29) < threshold
                    new_rad[nx, ny] = true
                end
            end
        end
    end

    for x in 1:w, y in 1:h
        grid.radicalized[x, y] = new_rad[x, y]
    end
    return nothing
end

# --- Kill border turtles ---

struct RadBorderSystem <: System end

function update!(::RadBorderSystem, world::World)
    state = get_resource(world, RadState)
    grid = get_resource(world, RadGrid)
    w, h = grid.width, grid.height

    for tc in state.terrorist_clusters
        !tc.alive && continue
        if tc.x <= 1 || tc.x >= w || tc.y <= 1 || tc.y >= h
            tc.alive = false
        end
    end
    return nothing
end

# --- Terrorist Network Influence ---

struct RadNetworkSystem <: System end

function update!(::RadNetworkSystem, world::World)
    params = get_resource(world, RadParams)
    rng = get_resource(world, RNGResource).rng
    state = get_resource(world, RadState)
    grid = get_resource(world, RadGrid)
    n = length(state.terrorist_clusters)

    # 2% chance to re-link
    for i in 1:n
        !state.terrorist_clusters[i].alive && continue
        if rand(rng) < 0.02
            # Try to find a new connection
            for j in 1:n
                j == i && continue
                !state.terrorist_clusters[j].alive && continue
                nw_has_edge(state.network, i, j) && continue
                ci = state.terrorist_clusters[i]
                cj = state.terrorist_clusters[j]
                dist = sqrt(Float64((ci.x - cj.x)^2 + (ci.y - cj.y)^2))
                if dist <= params.link_distance && nw_degree(state.network, i) < params.degree
                    nw_add_edge!(state.network, i, j)
                    break
                end
            end
        end
    end

    # Influence spreads via network
    new_rad = [tc.radicalism for tc in state.terrorist_clusters]
    for i in 1:n
        !state.terrorist_clusters[i].alive && continue
        for j in nw_neighbors(state.network, i)
            j > n && continue
            !state.terrorist_clusters[j].alive && continue
            new_rad[i] += 0.01 * state.terrorist_clusters[j].radicalism
        end
    end
    for i in 1:n
        state.terrorist_clusters[i].radicalism = new_rad[i]
        # Radicalize patch at cluster position
        if state.terrorist_clusters[i].alive
            cx, cy = state.terrorist_clusters[i].x, state.terrorist_clusters[i].y
            if 1 <= cx <= grid.width && 1 <= cy <= grid.height
                grid.radicalized[cx, cy] = true
            end
        end
    end
    return nothing
end

# --- Township Check ---

struct RadTownshipSystem <: System end

function update!(::RadTownshipSystem, world::World)
    state = get_resource(world, RadState)
    grid = get_resource(world, RadGrid)

    for t in state.townships
        t.overtaken && continue
        if 1 <= t.x <= grid.width && 1 <= t.y <= grid.height
            if grid.radicalized[t.x, t.y]
                t.overtaken = true
            end
        end
    end
    return nothing
end

# --- Stats ---

struct RadStatsSystem <: System end

function update!(::RadStatsSystem, world::World)
    grid = get_resource(world, RadGrid)
    state = get_resource(world, RadState)
    _update_rad_stats!(grid, state, world)
    return nothing
end

# --- Termination ---

struct RadTerminationSystem <: System end

function update!(::RadTerminationSystem, world::World)
    params = get_resource(world, RadParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
