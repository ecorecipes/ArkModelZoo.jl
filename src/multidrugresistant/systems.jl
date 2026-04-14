# Multidrug Resistant systems
# Order: init → infection → patient_energy → move → termination

# --- Helpers ---
function _mdr_is_wall(elev::Float64)
    elev <= -9000.0 || elev >= 9999998.0
end

function _mdr_is_exit(elev::Float64)
    !_mdr_is_wall(elev) && abs(elev) < 0.5
end

function _mdr_is_walkable(grid::MDRGrid, x::Int, y::Int)
    (x < 1 || x > grid.width || y < 1 || y > grid.height) && return false
    return !_mdr_is_wall(grid.elevation[x, y])
end

function _mdr_is_room(grid::MDRGrid, x::Int, y::Int)
    _mdr_is_walkable(grid, x, y) && !_mdr_is_exit(grid.elevation[x, y])
end

# --- Initialization ---
struct InitMDRSystem <: System end

function initialize!(::InitMDRSystem, world::World)
    params = get_resource(world, MDRParams)
    rng    = get_resource(world, RNGResource).rng
    grid   = get_resource(world, MDRGrid)

    # Load raster and apply to grid
    raster = gis_load_asc(params.data_path)
    env = gis_envelope(raster)
    transform = gis_set_world_envelope(env, -102.0, 102.0, -64.0, 64.0)
    grid.elevation = gis_apply_raster(raster, 205, 129, transform)
    grid.p_infected .= false

    # Find valid room patches (lower floors: NL y in -64..-53 or -45..-34)
    # grid_y = nly + 65 → y_ranges: 1..12 and 20..31
    room_patches = Tuple{Int,Int}[]
    for x in 1:grid.width, y in 1:grid.height
        if _mdr_is_room(grid, x, y) && (y <= 12 || (20 <= y <= 31))
            push!(room_patches, (x, y))
        end
    end

    # All walkable non-exit patches (for nurses/cleaners)
    all_room = Tuple{Int,Int}[]
    for x in 1:grid.width, y in 1:grid.height
        if _mdr_is_room(grid, x, y)
            push!(all_room, (x, y))
        end
    end

    # Fallback: if room_patches is too small, use all_room
    if length(room_patches) < params.num_patients
        room_patches = all_room
    end
    if isempty(all_room)
        # Emergency fallback: use any non-wall cell
        for x in 1:grid.width, y in 1:grid.height
            if !_mdr_is_wall(grid.elevation[x, y])
                push!(all_room, (x, y))
            end
        end
        if isempty(room_patches)
            room_patches = all_room
        end
    end

    # Place patients
    for i in 1:params.num_patients
        idx = rand(rng, 1:length(room_patches))
        px, py = room_patches[idx]
        inf = MDRInfection(i == 1, 2419200.0)  # first patient infected
        heading = rand(rng) * 360.0
        new_entity!(world, (MDRPosition(px, py), MDRHeading(heading), PatientTag(), inf))
    end

    # Place nurses
    for _ in 1:params.num_nurses
        idx = rand(rng, 1:length(all_room))
        nx, ny = all_room[idx]
        heading = rand(rng) * 360.0
        new_entity!(world, (MDRPosition(nx, ny), MDRHeading(heading), NurseTag(), MDRInfection(false, 0.0)))
    end

    # Place cleaners
    for _ in 1:params.num_cleaners
        idx = rand(rng, 1:length(all_room))
        cx, cy = all_room[idx]
        heading = rand(rng) * 360.0
        new_entity!(world, (MDRPosition(cx, cy), MDRHeading(heading), CleanerTag(), MDRInfection(false, 0.0)))
    end

    return nothing
end

# --- Infection spread ---
struct MDRInfectionSystem <: System end

function update!(::MDRInfectionSystem, world::World)
    rng  = get_resource(world, RNGResource).rng
    grid = get_resource(world, MDRGrid)

    # Collect all agent positions and infection status
    agent_positions = Dict{Tuple{Int,Int}, Vector{Bool}}()

    # Patients
    for (_, positions, _, _, infections) in Query(world, (MDRPosition, MDRHeading, PatientTag, MDRInfection))
        @inbounds for i in eachindex(positions)
            pos = positions[i]
            key = (pos.x, pos.y)
            if !haskey(agent_positions, key)
                agent_positions[key] = Bool[]
            end
            push!(agent_positions[key], infections[i].infected)
            # Infected agents contaminate their patch
            if infections[i].infected
                grid.p_infected[pos.x, pos.y] = true
            end
        end
    end
    # Nurses
    for (_, positions, _, _, infections) in Query(world, (MDRPosition, MDRHeading, NurseTag, MDRInfection))
        @inbounds for i in eachindex(positions)
            pos = positions[i]
            key = (pos.x, pos.y)
            if !haskey(agent_positions, key)
                agent_positions[key] = Bool[]
            end
            push!(agent_positions[key], infections[i].infected)
            if infections[i].infected
                grid.p_infected[pos.x, pos.y] = true
            end
        end
    end
    # Cleaners
    for (_, positions, _, _, infections) in Query(world, (MDRPosition, MDRHeading, CleanerTag, MDRInfection))
        @inbounds for i in eachindex(positions)
            pos = positions[i]
            key = (pos.x, pos.y)
            if !haskey(agent_positions, key)
                agent_positions[key] = Bool[]
            end
            push!(agent_positions[key], infections[i].infected)
            if infections[i].infected
                grid.p_infected[pos.x, pos.y] = true
            end
        end
    end

    # Environmental spread: infected patches spread to neighbors (p=0.025% = 0.00025)
    new_infected = Set{Tuple{Int,Int}}()
    for x in 1:grid.width, y in 1:grid.height
        if grid.p_infected[x, y]
            for dx in -1:1, dy in -1:1
                (dx == 0 && dy == 0) && continue
                nx = x + dx
                ny = y + dy
                if _mdr_is_walkable(grid, nx, ny) && !grid.p_infected[nx, ny]
                    if rand(rng) < 0.00025
                        push!(new_infected, (nx, ny))
                    end
                end
            end
        end
    end
    for (nx, ny) in new_infected
        grid.p_infected[nx, ny] = true
    end

    # Agent-to-agent infection on shared patches
    has_infected_patch = Set{Tuple{Int,Int}}()
    for (key, statuses) in agent_positions
        if any(statuses)
            push!(has_infected_patch, key)
        end
    end

    # Infect agents on contaminated patches (from co-location or environmental)
    for (_, positions, _, _, infections) in Query(world, (MDRPosition, MDRHeading, PatientTag, MDRInfection))
        @inbounds for i in eachindex(positions)
            if !infections[i].infected
                key = (positions[i].x, positions[i].y)
                if key in has_infected_patch || grid.p_infected[positions[i].x, positions[i].y]
                    infections[i].infected = true
                end
            end
        end
    end
    for (_, positions, _, _, infections) in Query(world, (MDRPosition, MDRHeading, NurseTag, MDRInfection))
        @inbounds for i in eachindex(positions)
            if !infections[i].infected
                key = (positions[i].x, positions[i].y)
                if key in has_infected_patch || grid.p_infected[positions[i].x, positions[i].y]
                    infections[i].infected = true
                end
            end
        end
    end
    for (_, positions, _, _, infections) in Query(world, (MDRPosition, MDRHeading, CleanerTag, MDRInfection))
        @inbounds for i in eachindex(positions)
            if !infections[i].infected
                key = (positions[i].x, positions[i].y)
                if key in has_infected_patch || grid.p_infected[positions[i].x, positions[i].y]
                    infections[i].infected = true
                end
            end
        end
    end

    return nothing
end

# --- Patient energy and death/recovery ---
struct MDRPatientSystem <: System
    to_remove::Vector{Entity}
end
MDRPatientSystem() = MDRPatientSystem(Entity[])

function update!(system::MDRPatientSystem, world::World)
    rng   = get_resource(world, RNGResource).rng
    stats = get_resource(world, MDRStats)
    empty!(system.to_remove)

    for (eids, _, _, _, infections) in Query(world, (MDRPosition, MDRHeading, PatientTag, MDRInfection))
        @inbounds for i in eachindex(infections)
            if infections[i].infected
                infections[i].energy -= 1.0
                if infections[i].energy < 0.0
                    if rand(rng) < 0.44
                        stats.dead_patients += 1
                    else
                        stats.recovered_patients += 1
                    end
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

# --- Movement ---
struct MDRMoveSystem <: System end

function update!(::MDRMoveSystem, world::World)
    rng  = get_resource(world, RNGResource).rng
    grid = get_resource(world, MDRGrid)

    # Nurses: forward 1 if walkable, else turn ~180°
    for (_, positions, headings, _, _) in Query(world, (MDRPosition, MDRHeading, NurseTag, MDRInfection))
        @inbounds for i in eachindex(positions)
            pos = positions[i]
            h   = headings[i]
            rad = deg2rad(h.heading)
            dx = round(Int, sin(rad))
            dy = round(Int, cos(rad))
            nx = pos.x + dx
            ny = pos.y + dy
            if _mdr_is_walkable(grid, nx, ny)
                pos.x = nx
                pos.y = ny
            else
                h.heading = mod(h.heading + 180.0 + (rand(rng) * 40.0 - 20.0), 360.0)
            end
        end
    end

    # Cleaners: random walk
    for (_, positions, headings, _, _) in Query(world, (MDRPosition, MDRHeading, CleanerTag, MDRInfection))
        @inbounds for i in eachindex(positions)
            pos = positions[i]
            h   = headings[i]
            h.heading = rand(rng) * 360.0
            rad = deg2rad(h.heading)
            dx = round(Int, sin(rad))
            dy = round(Int, cos(rad))
            nx = pos.x + dx
            ny = pos.y + dy
            if _mdr_is_walkable(grid, nx, ny)
                pos.x = nx
                pos.y = ny
            end
        end
    end

    return nothing
end

# --- Termination ---
struct MDRTerminationSystem <: System end

function update!(::MDRTerminationSystem, world::World)
    params = get_resource(world, MDRParams)
    tick   = get_resource(world, Tick)

    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
        return nothing
    end

    # Check: all patients infected?
    all_infected = true
    any_patient = false
    for (_, _, _, _, infections) in Query(world, (MDRPosition, MDRHeading, PatientTag, MDRInfection))
        @inbounds for i in eachindex(infections)
            any_patient = true
            if !infections[i].infected
                all_infected = false
            end
        end
    end

    if any_patient && all_infected
        get_resource(world, Terminate).stop = true
    end

    return nothing
end
