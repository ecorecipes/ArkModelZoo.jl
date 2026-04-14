# Bomb Scenario systems
# Order: init → spawn → citizen_move → officer_patrol → termination

# --- Initialization ---
struct InitBombSystem <: System end

function _bomb_walkable(grid::BombGrid, x::Int, y::Int)
    (x < 1 || x > grid.width || y < 1 || y > grid.height) && return false
    return grid.patch_type[x, y] > 0.0
end

function initialize!(::InitBombSystem, world::World)
    params = get_resource(world, BombParams)
    rng    = get_resource(world, RNGResource).rng
    grid   = get_resource(world, BombGrid)

    # Load raster and apply to grid
    raster = gis_load_asc(params.data_path)
    env = gis_envelope(raster)
    transform = gis_set_world_envelope(env, -46.0, 46.0, -267.0, 267.0)
    grid.patch_type = gis_apply_raster(raster, 93, 535, transform)

    # Replace nodata with 0 (walls)
    for i in eachindex(grid.patch_type)
        if grid.patch_type[i] < -9000.0
            grid.patch_type[i] = 0.0
        end
    end

    # Create 5 officers on random walkable patches
    walkable = Tuple{Int,Int}[]
    for x in 1:grid.width, y in 1:grid.height
        if grid.patch_type[x, y] > 0.0
            push!(walkable, (x, y))
        end
    end

    for _ in 1:min(5, length(walkable))
        idx = rand(rng, 1:length(walkable))
        wx, wy = walkable[idx]
        new_entity!(world, (BombPosition(wx, wy), OfficerTag()))
    end

    return nothing
end

# --- Spawn citizens every 5 ticks ---
struct BombSpawnSystem <: System end

function update!(::BombSpawnSystem, world::World)
    tick = get_resource(world, Tick)
    rng  = get_resource(world, RNGResource).rng
    grid = get_resource(world, BombGrid)

    # NL (28, -90) → grid (75, 178)
    spawn_x, spawn_y = 75, 178

    if tick.tick % 5 == 0
        for _ in 1:45
            dir = rand(rng, 0:1)
            state = BombCitizenState(dir, 0.0)
            new_entity!(world, (BombPosition(spawn_x, spawn_y), CitizenTag(), state))
        end
    end

    # Bombers every 200 ticks (won't trigger with max_ticks=50)
    if tick.tick > 0 && tick.tick % 200 == 0
        if _bomb_walkable(grid, spawn_x, spawn_y)
            new_entity!(world, (BombPosition(spawn_x, spawn_y), BomberTag()))
        end
    end

    return nothing
end

# --- Citizen movement and suspiciousness ---
struct BombCitizenMoveSystem <: System end

function update!(::BombCitizenMoveSystem, world::World)
    rng  = get_resource(world, RNGResource).rng
    grid = get_resource(world, BombGrid)

    for (_, positions, _, states) in Query(world, (BombPosition, CitizenTag, BombCitizenState))
        @inbounds for i in eachindex(positions)
            pos   = positions[i]
            state = states[i]
            state.suspiciousness += 1.0

            # Move to best walkable Moore neighbor (highest patch_type value)
            best_val = -Inf
            best_x, best_y = pos.x, pos.y
            for dx in -1:1, dy in -1:1
                (dx == 0 && dy == 0) && continue
                nx = pos.x + dx
                ny = pos.y + dy
                if _bomb_walkable(grid, nx, ny)
                    # Prefer direction based on goingDirection
                    dir_bonus = state.going_direction == 0 ? Float64(dy) : Float64(-dy)
                    val = grid.patch_type[nx, ny] + dir_bonus * 0.1
                    if val > best_val
                        best_val = val
                        best_x = nx
                        best_y = ny
                    end
                end
            end
            pos.x = best_x
            pos.y = best_y
        end
    end
    return nothing
end

# --- Officer patrol and arrests ---
struct BombOfficerSystem <: System
    to_arrest::Vector{Entity}
end
BombOfficerSystem() = BombOfficerSystem(Entity[])

function update!(system::BombOfficerSystem, world::World)
    grid  = get_resource(world, BombGrid)
    rng   = get_resource(world, RNGResource).rng
    stats = get_resource(world, BombStats)
    empty!(system.to_arrest)

    # Collect citizen positions and suspiciousness
    citizen_data = Tuple{Entity, Int, Int, Float64}[]
    for (eids, positions, _, states) in Query(world, (BombPosition, CitizenTag, BombCitizenState))
        @inbounds for i in eachindex(positions)
            push!(citizen_data, (eids[i], positions[i].x, positions[i].y, states[i].suspiciousness))
        end
    end

    # Officers move toward most suspicious nearby citizen and arrest
    for (_, positions, _) in Query(world, (BombPosition, OfficerTag))
        @inbounds for i in eachindex(positions)
            pos = positions[i]

            # Find most suspicious citizen within radius 5
            best_susp = -1.0
            best_cx, best_cy = pos.x, pos.y
            best_eid = nothing
            for (ceid, cx, cy, susp) in citizen_data
                dist = abs(cx - pos.x) + abs(cy - pos.y)
                if dist <= 5 && susp > best_susp
                    best_susp = susp
                    best_cx = cx
                    best_cy = cy
                    best_eid = ceid
                end
            end

            # Move toward that citizen
            if best_susp > 0.0
                dx = sign(best_cx - pos.x)
                dy = sign(best_cy - pos.y)
                nx = pos.x + dx
                ny = pos.y + dy
                if _bomb_walkable(grid, nx, ny)
                    pos.x = nx
                    pos.y = ny
                end
            else
                # Random patrol on walkable patches
                dx = rand(rng, -1:1)
                dy = rand(rng, -1:1)
                nx = pos.x + dx
                ny = pos.y + dy
                if _bomb_walkable(grid, nx, ny)
                    pos.x = nx
                    pos.y = ny
                end
            end

            # Arrest adjacent citizens with suspiciousness > 1250
            if best_eid !== nothing && best_susp > 1250.0
                dist = abs(best_cx - pos.x) + abs(best_cy - pos.y)
                if dist <= 1
                    push!(system.to_arrest, best_eid)
                    stats.arrested_total += 1
                end
            end
        end
    end

    for eid in system.to_arrest
        is_alive(world, eid) && remove_entity!(world, eid)
    end
    return nothing
end

# --- Termination ---
struct BombTerminationSystem <: System end

function update!(::BombTerminationSystem, world::World)
    params = get_resource(world, BombParams)
    tick   = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
