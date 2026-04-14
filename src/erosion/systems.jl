struct InitErosionSystem <: System end

function initialize!(::InitErosionSystem, world::World)
    params = get_resource(world, ERParams)
    rng = get_resource(world, RNGResource).rng
    g = get_resource(world, ERGrid)
    w, h = g.width, g.height
    cx, cy = (w + 1) / 2.0, (h + 1) / 2.0
    max_dist = max(cx - 1, cy - 1)

    for x in 1:w, y in 1:h
        if params.bumpy
            dist = sqrt((x - cx)^2 + (y - cy)^2)
            if params.hill
                g.elevation[x, y] = -100.0 * (dist / max_dist) + 100.0 + Float64(rand(rng, 0:99))
            else
                g.elevation[x, y] = Float64(rand(rng, 0:124))
            end
        else
            g.elevation[x, y] = 100.0
        end
        g.water[x, y] = 0.0
        g.drain[x, y] = false
    end

    # Smooth terrain via diffusion (NetLogo: diffuse elevation 0.5)
    # NetLogo diffuse: each patch shares rate/8 of its value with each of its
    # existing neighbors; shares to non-existent neighbors are kept by the patch.
    if params.bumpy
        old = similar(g.elevation)
        rate8 = 0.5 / 8.0
        for _ in 1:params.terrain_smoothness
            copyto!(old, g.elevation)
            for x in 1:w, y in 1:h
                s = 0.0; n_nbrs = 0
                for dx in -1:1, dy in -1:1
                    (dx == 0 && dy == 0) && continue
                    nx, ny = x + dx, y + dy
                    if 1 <= nx <= w && 1 <= ny <= h
                        s += old[nx, ny]; n_nbrs += 1
                    end
                end
                g.elevation[x, y] = old[x, y] * (1.0 - n_nbrs * rate8) + s * rate8
            end
        end
    end

    # Mark edge patches as drains
    for x in 1:w, y in 1:h
        is_edge = (x == 1 || x == w || y == 1 || y == h)
        if is_edge
            g.drain[x, y] = true
            g.elevation[x, y] = -1e7
        end
    end

    _er_update_stats!(world)
    return nothing
end

struct ErosionGoSystem <: System end

function update!(::ErosionGoSystem, world::World)
    params = get_resource(world, ERParams)
    rng = get_resource(world, RNGResource).rng
    g = get_resource(world, ERGrid)
    w, h = g.width, g.height

    # Rainfall on land patches
    for x in 1:w, y in 1:h
        g.drain[x, y] && continue
        if rand(rng) < params.rainfall
            g.water[x, y] += 1.0
        end
    end

    # Flow — shuffle land patch order (NetLogo ask agentset is random order)
    land_patches = [(x, y) for x in 1:w for y in 1:h if !g.drain[x, y]]
    Random.shuffle!(rng, land_patches)

    for (x, y) in land_patches
        g.water[x, y] <= 0.0 && continue
        # Find neighbor with lowest (elevation + water)
        best_x, best_y = x, y
        best_level = g.elevation[x, y] + g.water[x, y]
        for dx in -1:1, dy in -1:1
            (dx == 0 && dy == 0) && continue
            nx, ny = x + dx, y + dy
            (nx < 1 || nx > w || ny < 1 || ny > h) && continue
            level = g.elevation[nx, ny] + g.water[nx, ny]
            if level < best_level
                best_level = level
                best_x = nx
                best_y = ny
            end
        end
        (best_x == x && best_y == y) && continue

        my_level = g.elevation[x, y] + g.water[x, y]
        target_level = g.elevation[best_x, best_y] + g.water[best_x, best_y]
        amount = min(g.water[x, y], 0.5 * (my_level - target_level))
        amount <= 0.0 && continue

        # Erosion
        erosion = amount * (1.0 - params.soil_hardness)
        g.elevation[x, y] -= erosion

        # Recalculate amount after erosion changed elevation
        my_level = g.elevation[x, y] + g.water[x, y]
        target_level = g.elevation[best_x, best_y] + g.water[best_x, best_y]
        amount = min(g.water[x, y], 0.5 * (my_level - target_level))
        if amount > 0.0
            g.water[x, y] -= amount
            g.water[best_x, best_y] += amount
        end
    end

    # Reset drains
    for x in 1:w, y in 1:h
        if g.drain[x, y]
            g.water[x, y] = 0.0
            g.elevation[x, y] = -1e7
        end
    end

    _er_update_stats!(world)
    return nothing
end

function _er_update_stats!(world::World)
    g = get_resource(world, ERGrid)
    stats = get_resource(world, ERStats)
    w, h = g.width, g.height
    sum_elev = 0.0; sum_water = 0.0; n_land = 0
    for x in 1:w, y in 1:h
        g.drain[x, y] && continue
        sum_elev += g.elevation[x, y]
        sum_water += g.water[x, y]
        n_land += 1
    end
    stats.mean_elevation = n_land > 0 ? sum_elev / n_land : 0.0
    stats.total_water = sum_water
end

struct ErosionTerminationSystem <: System end

function update!(::ErosionTerminationSystem, world::World)
    params = get_resource(world, ERParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
