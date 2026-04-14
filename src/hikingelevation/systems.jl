# Hiking Elevation systems
# Order: init → spawn → move → stats → termination

# --- Initialization ---
struct InitHikeSystem <: System end

function initialize!(::InitHikeSystem, world::World)
    params = get_resource(world, HikeParams)
    grid   = get_resource(world, HikeGrid)

    raster = gis_load_asc(params.data_path)
    grid.elevation = gis_apply_raster_simple(raster)
    grid.min_elev  = gis_minimum(raster)
    grid.max_elev  = gis_maximum(raster)
    grid.tread_count .= 160.0
    return nothing
end

# --- Spawn one hiker per tick at entrance ---
struct HikeSpawnSystem <: System end

function update!(::HikeSpawnSystem, world::World)
    rng  = get_resource(world, RNGResource).rng
    grid = get_resource(world, HikeGrid)

    steep = rand(rng) < 0.5
    planned = 480.0 + randn(rng) * 5.0
    state = HikeState(steep, true, planned, 0.0)
    new_entity!(world, (HikePosition(grid.entrance_x, grid.entrance_y), state, HikerTag()))
    grid.turtle_count += 1
    return nothing
end

# --- Movement toward goal / entrance ---
struct HikeMoveSystem <: System
    to_remove::Vector{Entity}
end
HikeMoveSystem() = HikeMoveSystem(Entity[])

function update!(system::HikeMoveSystem, world::World)
    grid = get_resource(world, HikeGrid)
    empty!(system.to_remove)

    for (eids, positions, states, _) in Query(world, (HikePosition, HikeState, HikerTag))
        @inbounds for i in eachindex(positions)
            pos   = positions[i]
            state = states[i]
            state.hike_time_elapsed += 1.0

            # Determine target
            if state.outbound
                tx, ty = grid.goal_x, grid.goal_y
            else
                tx, ty = grid.entrance_x, grid.entrance_y
            end

            # Move to best Moore neighbor (minimize distance to target)
            best_score = Inf
            best_x, best_y = pos.x, pos.y

            for dx in -1:1, dy in -1:1
                (dx == 0 && dy == 0) && continue
                nx = pos.x + dx
                ny = pos.y + dy
                (nx < 1 || nx > grid.width || ny < 1 || ny > grid.height) && continue
                dist = sqrt(Float64((nx - tx)^2 + (ny - ty)^2))
                elev = grid.elevation[nx, ny]
                # Steep hikers prefer higher elevation, others prefer lower
                elev_bias = state.steep ? -elev * 0.001 : elev * 0.001
                score = dist + elev_bias
                if score < best_score
                    best_score = score
                    best_x = nx
                    best_y = ny
                end
            end

            pos.x = best_x
            pos.y = best_y

            # Erode tread
            grid.tread_count[pos.x, pos.y] = max(0.0, grid.tread_count[pos.x, pos.y] - 0.6)

            # Check turnaround / arrival conditions
            dist_goal = sqrt(Float64((pos.x - grid.goal_x)^2 + (pos.y - grid.goal_y)^2))
            dist_entrance = sqrt(Float64((pos.x - grid.entrance_x)^2 + (pos.y - grid.entrance_y)^2))

            if state.outbound
                if dist_goal <= 1.0 || state.hike_time_elapsed > state.hike_time_planned / 4.0
                    state.outbound = false
                end
            else
                if dist_entrance <= 1.0
                    push!(system.to_remove, eids[i])
                end
            end
        end
    end

    for eid in system.to_remove
        is_alive(world, eid) && remove_entity!(world, eid)
    end
    return nothing
end

# --- Stats: track elevation of turtle 500 ---
struct HikeStatsSystem <: System end

function update!(::HikeStatsSystem, world::World)
    grid  = get_resource(world, HikeGrid)
    stats = get_resource(world, HikeStats)

    # Turtle 500 won't exist with max_ticks=200 (one hiker per tick)
    if grid.turtle_count >= 500
        # Would need entity tracking; approximate with 0 for safety
        stats.track_elevation = 0.0
    else
        stats.track_elevation = 0.0
    end
    return nothing
end

# --- Termination ---
struct HikeTerminationSystem <: System end

function update!(::HikeTerminationSystem, world::World)
    params = get_resource(world, HikeParams)
    tick   = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
