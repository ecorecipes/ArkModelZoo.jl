# Wolf-Sheep Predation systems
# Matches NetLogo execution order:
#   ask sheep [ move; energy-=1; eat-grass; maybe-reproduce 4; if energy<=0 die ]
#   ask wolves [ move; energy-=1; eat-sheep; maybe-reproduce 5; if energy<=0 die ]
#   ask patches [ grow-grass ]
#   update-counts

# --- Initialization ---

struct InitWolfSheepSystem <: System end

function initialize!(::InitWolfSheepSystem, world::World)
    params = get_resource(world, WolfSheepParams)
    rng = get_resource(world, RNGResource).rng
    grass_grid = get_resource(world, GrassGrid)
    w, h = grass_grid.width, grass_grid.height

    # Initialize grass: countdown = random 0..(regrowth_time-1)
    if params.grass_enabled
        for x in 1:w, y in 1:h
            grass_grid.countdown[x, y] = rand(rng, 0:params.grass_regrowth_time-1)
        end
    end

    # Create sheep — energy = random 0..9, heading = random integer 0..359
    for _ in 1:params.initial_number_sheep
        x = rand(rng) * w
        y = rand(rng) * h
        e = Float64(rand(rng, 0:9))
        new_entity!(world, (WSPosition(x, y), Energy(e), WSHeading(Float64(rand(rng, 0:359))), Sheep()))
    end

    # Create wolves — energy = random 0..9, heading = random integer 0..359
    for _ in 1:params.initial_number_wolves
        x = rand(rng) * w
        y = rand(rng) * h
        e = Float64(rand(rng, 0:9))
        new_entity!(world, (WSPosition(x, y), Energy(e), WSHeading(Float64(rand(rng, 0:359))), Wolf()))
    end
    return nothing
end

# --- Shared movement helper ---
# NetLogo: rt random 50 - 25; fd 1 — persistent heading, ±25 degree turn, forward 1

function _ws_move!(rng, pos::WSPosition, heading::WSHeading, w::Int, h::Int)
    heading.angle += Float64(rand(rng, 0:49) - 25)
    θ = deg2rad(heading.angle)
    pos.x = mod(pos.x + sin(θ), Float64(w))
    pos.y = mod(pos.y + cos(θ), Float64(h))
end

# --- Sheep Phase ---
# All sheep: move, energy-=1, eat-grass, maybe-reproduce, die-check

mutable struct SheepPhaseSystem <: System
    new_sheep::Vector{Tuple{Float64, Float64, Float64, Float64}}  # x, y, energy, heading
end
SheepPhaseSystem() = SheepPhaseSystem(Tuple{Float64,Float64,Float64,Float64}[])

function update!(system::SheepPhaseSystem, world::World)
    params = get_resource(world, WolfSheepParams)
    rng = get_resource(world, RNGResource).rng
    grass_grid = get_resource(world, GrassGrid)
    w, h = grass_grid.width, grass_grid.height

    empty!(system.new_sheep)
    to_remove = Entity[]

    # NetLogo `ask` shuffles agentset each tick — randomize processing order
    for (eids, positions, energies, headings) in Query(world, (WSPosition, Energy, WSHeading); with=(Sheep,))
        indices = collect(eachindex(positions))
        Random.shuffle!(rng, indices)
        @inbounds for i in indices
            # Move + lose energy
            _ws_move!(rng, positions[i], headings[i], w, h)
            energies[i].energy -= 1.0

            # Eat grass
            if params.grass_enabled
                gx = clamp(floor(Int, positions[i].x) + 1, 1, w)
                gy = clamp(floor(Int, positions[i].y) + 1, 1, h)
                if grass_grid.countdown[gx, gy] <= 0
                    energies[i].energy += params.sheep_gain_from_food
                    grass_grid.countdown[gx, gy] = params.grass_regrowth_time
                end
            end

            # Maybe reproduce
            if rand(rng, 0:99) < round(Int, params.sheep_reproduce)
                energies[i].energy /= 2.0
                push!(system.new_sheep, (positions[i].x, positions[i].y,
                      energies[i].energy, headings[i].angle))
            end

            # Die check
            if energies[i].energy <= 0.0
                push!(to_remove, eids[i])
            end
        end
    end

    # Remove dead sheep
    for e in to_remove
        is_alive(world, e) && remove_entity!(world, e)
    end

    # Spawn offspring — NetLogo: hatch 1 [ rt random 360; fd 1 ] (integer turn)
    for (x, y, e, h_angle) in system.new_sheep
        new_heading = h_angle + Float64(rand(rng, 0:359))
        θ = deg2rad(new_heading)
        nx = mod(x + sin(θ), Float64(w))
        ny = mod(y + cos(θ), Float64(h))
        new_entity!(world, (WSPosition(nx, ny), Energy(e), WSHeading(new_heading), Sheep()))
    end
    return nothing
end

# --- Wolf Phase ---
# All wolves: move, energy-=1, eat-sheep, maybe-reproduce, die-check

mutable struct WolfPhaseSystem <: System
    sheep_by_cell::Dict{Tuple{Int,Int}, Vector{Entity}}
    new_wolves::Vector{Tuple{Float64, Float64, Float64, Float64}}
end
WolfPhaseSystem() = WolfPhaseSystem(
    Dict{Tuple{Int,Int}, Vector{Entity}}(),
    Tuple{Float64,Float64,Float64,Float64}[]
)

function update!(system::WolfPhaseSystem, world::World)
    params = get_resource(world, WolfSheepParams)
    rng = get_resource(world, RNGResource).rng
    grass_grid = get_resource(world, GrassGrid)
    w, h = grass_grid.width, grass_grid.height

    empty!(system.new_wolves)

    # Build sheep spatial index (after sheep phase, dead sheep already removed)
    empty!(system.sheep_by_cell)
    for (eids, positions) in Query(world, (WSPosition,); with=(Sheep,))
        @inbounds for i in eachindex(positions)
            gx = clamp(floor(Int, positions[i].x) + 1, 1, w)
            gy = clamp(floor(Int, positions[i].y) + 1, 1, h)
            key = (gx, gy)
            if !haskey(system.sheep_by_cell, key)
                system.sheep_by_cell[key] = Entity[]
            end
            push!(system.sheep_by_cell[key], eids[i])
        end
    end

    to_remove_wolves = Entity[]
    to_remove_sheep = Entity[]

    for (eids, positions, energies, headings) in Query(world, (WSPosition, Energy, WSHeading); with=(Wolf,))
        indices = collect(eachindex(positions))
        Random.shuffle!(rng, indices)
        @inbounds for i in indices
            # Move + lose energy
            _ws_move!(rng, positions[i], headings[i], w, h)
            energies[i].energy -= 1.0

            # Eat sheep
            gx = clamp(floor(Int, positions[i].x) + 1, 1, w)
            gy = clamp(floor(Int, positions[i].y) + 1, 1, h)
            key = (gx, gy)
            sheep_list = get(system.sheep_by_cell, key, nothing)
            if sheep_list !== nothing && !isempty(sheep_list)
                idx = rand(rng, 1:length(sheep_list))
                prey = sheep_list[idx]
                push!(to_remove_sheep, prey)
                deleteat!(sheep_list, idx)
                energies[i].energy += params.wolf_gain_from_food
            end

            # Maybe reproduce
            if rand(rng, 0:99) < round(Int, params.wolf_reproduce)
                energies[i].energy /= 2.0
                push!(system.new_wolves, (positions[i].x, positions[i].y,
                      energies[i].energy, headings[i].angle))
            end

            # Die check
            if energies[i].energy <= 0.0
                push!(to_remove_wolves, eids[i])
            end
        end
    end

    # Remove eaten sheep and dead wolves
    for e in to_remove_sheep
        is_alive(world, e) && remove_entity!(world, e)
    end
    for e in to_remove_wolves
        is_alive(world, e) && remove_entity!(world, e)
    end

    # Spawn wolf offspring — NetLogo: hatch 1 [ rt random 360; fd 1 ] (integer turn)
    for (x, y, e, h_angle) in system.new_wolves
        new_heading = h_angle + Float64(rand(rng, 0:359))
        θ = deg2rad(new_heading)
        nx = mod(x + sin(θ), Float64(w))
        ny = mod(y + cos(θ), Float64(h))
        new_entity!(world, (WSPosition(nx, ny), Energy(e), WSHeading(new_heading), Wolf()))
    end
    return nothing
end

# --- Grass Growth ---

struct GrassGrowthSystem <: System end

function update!(::GrassGrowthSystem, world::World)
    params = get_resource(world, WolfSheepParams)
    !params.grass_enabled && return nothing
    grass_grid = get_resource(world, GrassGrid)

    for x in 1:grass_grid.width, y in 1:grass_grid.height
        if grass_grid.countdown[x, y] > 0
            grass_grid.countdown[x, y] -= 1
        end
    end
    return nothing
end

# --- Count Population ---

struct CountWSPopulationSystem <: System end

function update!(::CountWSPopulationSystem, world::World)
    params = get_resource(world, WolfSheepParams)
    stats = get_resource(world, WSPopulationStats)

    sheep_count = 0
    for (eids, _) in Query(world, (WSPosition,); with=(Sheep,))
        sheep_count += length(eids)
    end

    wolf_count = 0
    for (eids, _) in Query(world, (WSPosition,); with=(Wolf,))
        wolf_count += length(eids)
    end

    grass_count = 0
    if params.grass_enabled
        grass_grid = get_resource(world, GrassGrid)
        for x in 1:grass_grid.width, y in 1:grass_grid.height
            if grass_grid.countdown[x, y] <= 0
                grass_count += 1
            end
        end
    end

    stats.sheep_count = sheep_count
    stats.wolf_count = wolf_count
    stats.grass_count = grass_count
    return nothing
end

# --- Termination ---

struct WSTerminationSystem <: System end

function update!(::WSTerminationSystem, world::World)
    stats = get_resource(world, WSPopulationStats)
    params = get_resource(world, WolfSheepParams)
    tick = get_resource(world, Tick)

    if stats.sheep_count == 0 && stats.wolf_count == 0
        get_resource(world, Terminate).stop = true
    elseif tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
