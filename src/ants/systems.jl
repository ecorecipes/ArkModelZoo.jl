# --- Initialization ---

struct InitAntsSystem <: System end

function _setup_nest!(grid::PatchGrid)
    cx = (grid.width + 1) ÷ 2
    cy = (grid.height + 1) ÷ 2
    for x in 1:grid.width, y in 1:grid.height
        dist = sqrt(Float64((x - cx)^2 + (y - cy)^2))
        grid.nest_scent[x, y] = max(0.0, 200.0 - dist)
        if dist < 5.0
            grid.nest[x, y] = true
        end
    end
end

function _setup_food!(grid::PatchGrid, rng)
    cx = (grid.width + 1) ÷ 2
    cy = (grid.height + 1) ÷ 2
    max_r = (grid.width - 1) ÷ 2

    # Three food sources at fixed relative positions
    sources = [
        (round(Int, cx + 0.6 * max_r), cy, 1),
        (round(Int, cx - 0.6 * max_r), round(Int, cy - 0.6 * max_r), 2),
        (round(Int, cx - 0.8 * max_r), round(Int, cy + 0.8 * max_r), 3),
    ]

    for (sx, sy, src_id) in sources
        for x in 1:grid.width, y in 1:grid.height
            dist = sqrt(Float64((x - sx)^2 + (y - sy)^2))
            if dist < 5.0
                grid.food[x, y] = rand(rng, 1:2)
                grid.food_source[x, y] = src_id
            end
        end
    end
end

function initialize!(::InitAntsSystem, world::World)
    params = get_resource(world, AntsParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, PatchGrid)

    _setup_nest!(grid)
    _setup_food!(grid, rng)

    # Compute initial total food remaining
    stats = get_resource(world, AntsStats)
    total = 0
    for x in 1:grid.width, y in 1:grid.height
        total += grid.food[x, y]
    end
    stats.total_food_remaining = total

    # Create ants at nest center
    cx = Float64((grid.width + 1) ÷ 2)
    cy = Float64((grid.height + 1) ÷ 2)
    for i in 1:params.population
        new_entity!(world, (
            AntPosition(cx, cy),
            Heading(rand(rng) * 360.0),
            AntID(i),
        ))
    end
    return nothing
end

# --- Foraging Behavior ---

struct ForagingBehaviorSystem <: System
    to_add_food::Vector{Entity}      # ants that found food (add CarryingFood)
    to_drop_food::Vector{Entity}     # ants at nest (remove CarryingFood)
end
ForagingBehaviorSystem() = ForagingBehaviorSystem(Entity[], Entity[])

function _grid_xy(pos::AntPosition, grid::PatchGrid)
    gx = clamp(round(Int, pos.x), 1, grid.width)
    gy = clamp(round(Int, pos.y), 1, grid.height)
    return gx, gy
end

function _scent_at_angle(pos::AntPosition, heading::Float64, offset::Float64,
                          grid::PatchGrid, field::Matrix{Float64})
    θ = deg2rad(heading + offset)
    nx = pos.x + sin(θ)
    ny = pos.y + cos(θ)
    gx = clamp(round(Int, nx), 1, grid.width)
    gy = clamp(round(Int, ny), 1, grid.height)
    return field[gx, gy]
end

function _uphill!(heading_comp::Heading, pos::AntPosition, grid::PatchGrid, field::Matrix{Float64})
    ahead = _scent_at_angle(pos, heading_comp.angle, 0.0, grid, field)
    right = _scent_at_angle(pos, heading_comp.angle, 45.0, grid, field)
    left = _scent_at_angle(pos, heading_comp.angle, -45.0, grid, field)
    if right > ahead || left > ahead
        if right > left
            heading_comp.angle += 45.0
        else
            heading_comp.angle -= 45.0
        end
    end
end

function update!(system::ForagingBehaviorSystem, world::World)
    grid = get_resource(world, PatchGrid)
    stats = get_resource(world, AntsStats)
    tick_val = get_resource(world, Tick).tick

    empty!(system.to_add_food)
    empty!(system.to_drop_food)

    # Ants NOT carrying food: look for food
    for (eids, positions, headings, antids) in Query(world, (AntPosition, Heading, AntID); without=(CarryingFood,))
        @inbounds for i in eachindex(positions)
            antids[i].who >= tick_val && continue

            gx, gy = _grid_xy(positions[i], grid)

            if grid.food[gx, gy] > 0
                grid.food[gx, gy] -= 1
                stats.total_food_collected += 1
                src = grid.food_source[gx, gy]
                if src == 1; stats.food_source1 += 1
                elseif src == 2; stats.food_source2 += 1
                elseif src == 3; stats.food_source3 += 1
                end
                headings[i].angle += 180.0
                push!(system.to_add_food, eids[i])
            else
                chem = grid.chemical[gx, gy]
                if chem >= 0.05 && chem < 2.0
                    _uphill!(headings[i], positions[i], grid, grid.chemical)
                end
            end
        end
    end

    # Ants carrying food: return to nest
    for (eids, positions, headings) in Query(world, (AntPosition, Heading); with=(CarryingFood,))
        @inbounds for i in eachindex(positions)
            gx, gy = _grid_xy(positions[i], grid)
            if grid.nest[gx, gy]
                headings[i].angle += 180.0
                push!(system.to_drop_food, eids[i])
            else
                grid.chemical[gx, gy] += 60.0
                _uphill!(headings[i], positions[i], grid, grid.nest_scent)
            end
        end
    end

    # Apply deferred component changes outside query iteration
    for e in system.to_add_food
        add_components!(world, e, (CarryingFood(),))
    end
    for e in system.to_drop_food
        remove_components!(world, e, (CarryingFood,))
    end
    return nothing
end

# --- Movement ---

struct AntMovementSystem <: System end

function update!(::AntMovementSystem, world::World)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, PatchGrid)
    tick_val = get_resource(world, Tick).tick
    w, h = grid.width, grid.height

    for (_, positions, headings, antids) in Query(world, (AntPosition, Heading, AntID))
        @inbounds for i in eachindex(positions)
            antids[i].who >= tick_val && continue

            # Wiggle: random ±40 degrees
            headings[i].angle += rand(rng) * 40.0
            headings[i].angle -= rand(rng) * 40.0

            # Move forward 1
            θ = deg2rad(headings[i].angle)
            nx = positions[i].x + sin(θ)
            ny = positions[i].y + cos(θ)

            # Bounce off walls
            if nx < 1.0 || nx > Float64(w) || ny < 1.0 || ny > Float64(h)
                headings[i].angle += 180.0
                θ = deg2rad(headings[i].angle)
                nx = positions[i].x + sin(θ)
                ny = positions[i].y + cos(θ)
            end

            positions[i].x = clamp(nx, 1.0, Float64(w))
            positions[i].y = clamp(ny, 1.0, Float64(h))
        end
    end
    return nothing
end

# --- Pheromone Diffusion & Evaporation ---

struct PheromoneSystem <: System
    buffer::Matrix{Float64}
end
PheromoneSystem(grid_size::Int) = PheromoneSystem(zeros(Float64, grid_size, grid_size))
PheromoneSystem() = PheromoneSystem(0)  # placeholder; re-created in init

function initialize!(system::PheromoneSystem, world::World)
    # No-op; buffer allocated at construction
    return nothing
end

function update!(system::PheromoneSystem, world::World)
    params = get_resource(world, AntsParams)
    grid = get_resource(world, PatchGrid)
    w, h = grid.width, grid.height
    chem = grid.chemical
    buf = system.buffer

    # Diffuse: each cell shares diffusion_rate% with 8 neighbors
    diff_frac = params.diffusion_rate / 100.0
    share = diff_frac / 8.0

    # NetLogo diffuse: edge/corner patches keep shares meant for non-existent
    # neighbors, preserving the global sum of chemical.
    @inbounds for x in 1:w, y in 1:h
        n_nbr = 0
        for dx in -1:1, dy in -1:1
            (dx == 0 && dy == 0) && continue
            nx = x + dx
            ny = y + dy
            if nx >= 1 && nx <= w && ny >= 1 && ny <= h
                n_nbr += 1
            end
        end
        buf[x, y] = chem[x, y] * (1.0 - n_nbr * share)
    end

    @inbounds for x in 1:w, y in 1:h
        contrib = chem[x, y] * share
        contrib == 0.0 && continue
        for dx in -1:1, dy in -1:1
            (dx == 0 && dy == 0) && continue
            nx = x + dx
            ny = y + dy
            (nx < 1 || nx > w || ny < 1 || ny > h) && continue
            buf[nx, ny] += contrib
        end
    end

    # Evaporate
    retention = (100.0 - params.evaporation_rate) / 100.0
    @inbounds for x in 1:w, y in 1:h
        chem[x, y] = buf[x, y] * retention
    end
    return nothing
end

# --- Update Food Stats ---

struct UpdateFoodStatsSystem <: System end

function update!(::UpdateFoodStatsSystem, world::World)
    grid = get_resource(world, PatchGrid)
    stats = get_resource(world, AntsStats)
    total = 0
    @inbounds for x in 1:grid.width, y in 1:grid.height
        total += grid.food[x, y]
    end
    stats.total_food_remaining = total
    return nothing
end

# --- Termination ---

struct AntsTerminationSystem <: System end

function update!(::AntsTerminationSystem, world::World)
    params = get_resource(world, AntsParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
