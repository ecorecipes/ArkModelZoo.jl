# Contagion SI Model Systems
# NetLogo go order: check-all-infected → infect-susceptibles → recolor → move → count → tick
# Execution order: infection → movement → stats → termination

# --- Initialization ---
# NetLogo: create-turtles 300; ask n-of 3 turtles [set infected? true]

struct InitContagionSISystem <: System end

function initialize!(::InitContagionSISystem, world::World)
    params = get_resource(world, ContagionSIParams)
    rng = get_resource(world, RNGResource).rng
    stats = get_resource(world, CIStats)
    wf = Float64(params.grid_width)
    hf = Float64(params.grid_height)

    init_infected = min(params.init_infected, params.num_turtles)

    # Create all agents as susceptible with random positions and headings
    for _ in 1:params.num_turtles
        x = rand(rng) * wf
        y = rand(rng) * hf
        heading = Float64(rand(rng, 0:359))
        new_entity!(world, (CIPosition(x, y), CIHeading(heading), CISusceptible()))
    end

    # Select initial infected: n-of init-infected turtles
    all_entities = Entity[]
    for (eids, _) in Query(world, (CIPosition,); with=(CISusceptible,))
        @inbounds for i in eachindex(eids)
            push!(all_entities, eids[i])
        end
    end
    Random.shuffle!(rng, all_entities)
    for i in 1:init_infected
        exchange_components!(world, all_entities[i];
            add = (CIInfected(),),
            remove = (CISusceptible,),
        )
    end

    stats.n_infected = init_infected
    return nothing
end

# --- Infection ---
# NetLogo: ask turtles with [not infected?] [
#   let infected-neighbors (count other turtles with [color = red] in-radius 1)
#   if random-float 1 < 1 - (((1 - transmissibility) ^ infected-neighbors) * (1 - spontaneous-infect))
#     [set infected? true]
# ]
#
# `color = red` reflects previous tick's recolor, so new infections this tick
# are NOT counted as infected neighbors. We batch: all decisions use the
# start-of-tick infected set, then apply transitions at the end.

struct CIInfectionSystem <: System
    infected_cells::Dict{Tuple{Int,Int}, Vector{Tuple{Entity, Float64, Float64}}}
    to_infect::Vector{Entity}
end
CIInfectionSystem() = CIInfectionSystem(
    Dict{Tuple{Int,Int}, Vector{Tuple{Entity, Float64, Float64}}}(),
    Entity[],
)

function update!(system::CIInfectionSystem, world::World)
    params = get_resource(world, ContagionSIParams)
    rng = get_resource(world, RNGResource).rng
    w = params.grid_width
    h = params.grid_height
    wf = Float64(w)
    hf = Float64(h)

    empty!(system.infected_cells)
    empty!(system.to_infect)

    # Build spatial index of infected turtles (start-of-tick snapshot)
    for (eids, positions) in Query(world, (CIPosition,); with=(CIInfected,))
        @inbounds for i in eachindex(positions)
            cx = mod(floor(Int, positions[i].x), w) + 1
            cy = mod(floor(Int, positions[i].y), h) + 1
            key = (cx, cy)
            if !haskey(system.infected_cells, key)
                system.infected_cells[key] = Tuple{Entity, Float64, Float64}[]
            end
            push!(system.infected_cells[key], (eids[i], positions[i].x, positions[i].y))
        end
    end

    # Collect susceptible turtles
    susceptibles = Tuple{Entity, Float64, Float64}[]
    for (eids, positions) in Query(world, (CIPosition,); with=(CISusceptible,))
        @inbounds for i in eachindex(positions)
            push!(susceptibles, (eids[i], positions[i].x, positions[i].y))
        end
    end

    # NetLogo `ask` shuffles the agentset
    Random.shuffle!(rng, susceptibles)

    transmissibility = params.transmissibility
    spontaneous_infect = params.spontaneous_infect

    for (eid, sx, sy) in susceptibles
        # Count infected neighbors within radius 1 (toroidal, excluding self)
        cx = mod(floor(Int, sx), w) + 1
        cy = mod(floor(Int, sy), h) + 1

        infected_neighbors = 0
        for dx in -1:1, dy in -1:1
            nx = mod(cx - 1 + dx, w) + 1
            ny = mod(cy - 1 + dy, h) + 1
            targets = get(system.infected_cells, (nx, ny), nothing)
            targets === nothing && continue

            for (target_eid, tx, ty) in targets
                target_eid == eid && continue  # `other` keyword
                ddx = abs(sx - tx)
                ddx = min(ddx, wf - ddx)
                ddy = abs(sy - ty)
                ddy = min(ddy, hf - ddy)
                dist_sq = ddx * ddx + ddy * ddy
                if dist_sq <= 1.0  # in-radius 1
                    infected_neighbors += 1
                end
            end
        end

        # Infection probability: 1 - ((1 - τ)^n * (1 - σ))
        prob = 1.0 - ((1.0 - transmissibility) ^ infected_neighbors * (1.0 - spontaneous_infect))
        if rand(rng) < prob
            push!(system.to_infect, eid)
        end
    end

    # Apply all infection transitions (Susceptible → Infected)
    for eid in system.to_infect
        is_alive(world, eid) || continue
        exchange_components!(world, eid;
            add = (CIInfected(),),
            remove = (CISusceptible,),
        )
    end
    return nothing
end

# --- Movement ---
# NetLogo: left random turning-angle; right random turning-angle; fd speed
# Two independent integer draws in [0, turning_angle-1].

struct CIMovementSystem <: System end

function update!(::CIMovementSystem, world::World)
    rng = get_resource(world, RNGResource).rng
    params = get_resource(world, ContagionSIParams)
    wf = Float64(params.grid_width)
    hf = Float64(params.grid_height)
    ta = params.turning_angle
    spd = params.speed

    for (_, positions, headings) in Query(world, (CIPosition, CIHeading))
        @inbounds for i in eachindex(positions)
            headings[i].angle -= Float64(rand(rng, 0:ta-1))
            headings[i].angle += Float64(rand(rng, 0:ta-1))
            θ = deg2rad(headings[i].angle)
            positions[i].x = mod(positions[i].x + sin(θ) * spd, wf)
            positions[i].y = mod(positions[i].y + cos(θ) * spd, hf)
        end
    end
    return nothing
end

# --- Statistics ---
# NetLogo: set n-infected count turtles with [infected?]

struct CIStatsSystem <: System end

function update!(::CIStatsSystem, world::World)
    stats = get_resource(world, CIStats)
    i_count = 0
    for (eids, _) in Query(world, (CIPosition,); with=(CIInfected,))
        i_count += length(eids)
    end
    stats.n_infected = i_count
    return nothing
end

# --- Termination ---
# NetLogo: if (count turtles with [infected?]) = num-turtles [stop]

struct CITerminationSystem <: System end

function update!(::CITerminationSystem, world::World)
    params = get_resource(world, ContagionSIParams)
    tick = get_resource(world, Tick)
    stats = get_resource(world, CIStats)
    if stats.n_infected == params.num_turtles || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
