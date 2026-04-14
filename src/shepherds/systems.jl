# --- Initialization ---

struct InitSHSystem <: System end

function initialize!(::InitSHSystem, world::World)
    params = get_resource(world, SHParams)
    rng = get_resource(world, RNGResource).rng
    w, h = params.grid_width, params.grid_height

    # Create sheep
    for _ in 1:params.num_sheep
        sx = rand(rng) * w
        sy = rand(rng) * h
        heading = rand(rng) * 360.0
        new_entity!(world, (SHSheepPos(sx, sy, heading, false),))
    end

    # Create shepherds
    for _ in 1:params.num_shepherds
        sx = rand(rng) * w
        sy = rand(rng) * h
        heading = rand(rng) * 360.0
        new_entity!(world, (SHShepherdState(sx, sy, heading, zero_entity, false),))
    end
    return nothing
end

# --- Go ---

struct SHGoSystem <: System end

function update!(::SHGoSystem, world::World)
    params = get_resource(world, SHParams)
    rng = get_resource(world, RNGResource).rng
    w, h = Float64(params.grid_width), Float64(params.grid_height)

    # Collect shepherds
    shepherds = Tuple{Entity, Int}[]
    for (eids, states) in Query(world, (SHShepherdState,))
        @inbounds for i in eachindex(states)
            push!(shepherds, (eids[i], i))
        end
    end
    Random.shuffle!(rng, shepherds)

    # Build spatial index of visible sheep positions (cell -> list of sheep entities)
    sheep_at = Dict{Tuple{Int,Int}, Vector{Entity}}()
    for (eids, sheeps) in Query(world, (SHSheepPos,))
        @inbounds for i in eachindex(sheeps)
            s = sheeps[i]
            s.hidden && continue
            cx = clamp(floor(Int, s.x) + 1, 1, params.grid_width)
            cy = clamp(floor(Int, s.y) + 1, 1, params.grid_height)
            key = (cx, cy)
            if haskey(sheep_at, key)
                push!(sheep_at[key], eids[i])
            else
                sheep_at[key] = [eids[i]]
            end
        end
    end

    for (eid, _) in shepherds
        sh = get_components(world, eid, (SHShepherdState,))[1]
        cx = clamp(floor(Int, sh.x) + 1, 1, params.grid_width)
        cy = clamp(floor(Int, sh.y) + 1, 1, params.grid_height)
        key = (cx, cy)

        if is_zero(sh.carried_sheep)
            # Search for sheep at current cell
            local_sheep = get(sheep_at, key, Entity[])
            visible = filter(e -> begin
                sp = get_components(world, e, (SHSheepPos,))[1]
                !sp.hidden
            end, local_sheep)
            if !isempty(visible)
                picked = visible[rand(rng, 1:length(visible))]
                sp = get_components(world, picked, (SHSheepPos,))[1]
                sp.hidden = true
                sh.carried_sheep = picked
                # Step forward 1
                _sh_fd!(sh, 1.0, w, h)
            end
        elseif sh.found_herd
            # Find empty spot - check if any visible sheep here
            local_sheep = get(sheep_at, key, Entity[])
            visible_here = filter(e -> begin
                sp = get_components(world, e, (SHSheepPos,))[1]
                !sp.hidden
            end, local_sheep)
            if isempty(visible_here)
                # Drop sheep
                carried = get_components(world, sh.carried_sheep, (SHSheepPos,))[1]
                carried.x = sh.x
                carried.y = sh.y
                carried.hidden = false
                # Re-index
                ncx = clamp(floor(Int, sh.x) + 1, 1, params.grid_width)
                ncy = clamp(floor(Int, sh.y) + 1, 1, params.grid_height)
                nkey = (ncx, ncy)
                if haskey(sheep_at, nkey)
                    push!(sheep_at[nkey], sh.carried_sheep)
                else
                    sheep_at[nkey] = [sh.carried_sheep]
                end
                sh.carried_sheep = zero_entity
                sh.found_herd = false
                sh.heading = rand(rng) * 360.0
                _sh_fd!(sh, 20.0, w, h)
            end
        else
            # Find new herd - check if visible sheep here
            local_sheep = get(sheep_at, key, Entity[])
            visible_here = filter(e -> begin
                sp = get_components(world, e, (SHSheepPos,))[1]
                !sp.hidden
            end, local_sheep)
            if !isempty(visible_here)
                sh.found_herd = true
            end
        end

        # Wiggle and move (triangular distribution matching NetLogo: random 50 - random 50)
        sh.heading += rand(rng, 0:49) - rand(rng, 0:49)
        _sh_fd!(sh, 1.0, w, h)

        # Bring carried sheep along
        if !is_zero(sh.carried_sheep)
            carried = get_components(world, sh.carried_sheep, (SHSheepPos,))[1]
            carried.x = sh.x
            carried.y = sh.y
        end
    end

    # Move visible sheep
    sheep_list = Tuple{Entity, Int}[]
    for (eids, sheeps) in Query(world, (SHSheepPos,))
        @inbounds for i in eachindex(sheeps)
            push!(sheep_list, (eids[i], i))
        end
    end
    Random.shuffle!(rng, sheep_list)

    for (eid, _) in sheep_list
        sp = get_components(world, eid, (SHSheepPos,))[1]
        sp.hidden && continue
        sp.heading += rand(rng, 0:49) - rand(rng, 0:49)
        θ = deg2rad(sp.heading)
        sp.x = mod(sp.x + sin(θ) * params.sheep_speed, w)
        sp.y = mod(sp.y + cos(θ) * params.sheep_speed, h)
    end
    return nothing
end

function _sh_fd!(state, dist::Float64, w::Float64, h::Float64)
    θ = deg2rad(state.heading)
    state.x = mod(state.x + sin(θ) * dist, w)
    state.y = mod(state.y + cos(θ) * dist, h)
end

# --- Stats Update ---

struct SHStatsSystem <: System end

function update!(::SHStatsSystem, world::World)
    params = get_resource(world, SHParams)
    stats = get_resource(world, SHStats)
    grid = get_resource(world, SHGrid)
    w, h = params.grid_width, params.grid_height

    # Count ALL sheep per patch (including hidden) for sheepless-neighborhoods
    all_sheep_count = fill(0, w, h)
    # Count VISIBLE sheep per patch for denominator + num_sheep_visible
    fill!(grid.sheep_count, 0)
    num_visible = 0

    for (_, sheeps) in Query(world, (SHSheepPos,))
        @inbounds for i in eachindex(sheeps)
            s = sheeps[i]
            cx = clamp(floor(Int, s.x) + 1, 1, w)
            cy = clamp(floor(Int, s.y) + 1, 1, h)
            all_sheep_count[cx, cy] += 1
            if !s.hidden
                num_visible += 1
                grid.sheep_count[cx, cy] += 1
            end
        end
    end

    # sheepless-neighborhoods: patches where sum of ALL sheep in 8 neighbors == 0
    sheepless = 0
    for x in 1:w, y in 1:h
        nearby = 0
        for dx in -1:1, dy in -1:1
            (dx == 0 && dy == 0) && continue
            nx = mod1(x + dx, w)
            ny = mod1(y + dy, h)
            nearby += all_sheep_count[nx, ny]
        end
        if nearby == 0
            sheepless += 1
        end
    end

    # Denominator: patches with no VISIBLE sheep
    patches_without_visible = 0
    for x in 1:w, y in 1:h
        if grid.sheep_count[x, y] == 0
            patches_without_visible += 1
        end
    end

    stats.num_sheep_visible = num_visible
    if num_visible > 0 && patches_without_visible > 0
        stats.herding_efficiency = (sheepless / patches_without_visible) * 100.0
    else
        stats.herding_efficiency = 0.0
    end
    return nothing
end

# --- Termination ---

struct SHTerminationSystem <: System end

function update!(::SHTerminationSystem, world::World)
    params = get_resource(world, SHParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
