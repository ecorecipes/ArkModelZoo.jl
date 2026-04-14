# Virus on a Network – ECS systems matching the NetLogo reference.
# Execution order: init → spread+recover → resistance → stats → termination
#
# The spread and recovery logic are combined in VirusSpreadSystem because
# NetLogo executes them in a single `ask turtles with [infected?]` block
# where each turtle spreads, increments its timer, and checks recovery
# before the next turtle is processed.

# --- Initialization ---
# NetLogo: create-turtles 150 [...]; ask turtles [create-links-with other turtles in-radius 3];
#          ask n-of 3 turtles [become-infected]; update-counts

struct InitVirusSystem <: System end

function initialize!(::InitVirusSystem, world::World)
    params = get_resource(world, VirusParams)
    rng = get_resource(world, RNGResource).rng
    network = get_resource(world, VirusNetwork)
    stats = get_resource(world, VirusStats)
    wf = Float64(params.world_width)
    hf = Float64(params.world_height)

    # Create turtles with random positions and headings
    entities = Entity[]
    positions = Tuple{Float64,Float64}[]
    for _ in 1:params.number_people
        x = rand(rng) * wf
        y = rand(rng) * hf
        heading = Float64(rand(rng, 0:359))
        e = new_entity!(world, (
            VPosition(x, y),
            VHeading(heading),
            VirusState(VSusceptible),
            VirusTimer(0),
        ))
        push!(entities, e)
        push!(positions, (x, y))
    end

    # Build static contact network (undirected): link all pairs within radius
    for i in 1:params.number_people
        network.neighbors[entities[i]] = Entity[]
    end
    r2 = params.link_radius * params.link_radius
    for i in 1:params.number_people
        xi, yi = positions[i]
        for j in (i + 1):params.number_people
            dx = abs(xi - positions[j][1])
            dx = min(dx, wf - dx)
            dy = abs(yi - positions[j][2])
            dy = min(dy, hf - dy)
            if dx * dx + dy * dy <= r2
                push!(network.neighbors[entities[i]], entities[j])
                push!(network.neighbors[entities[j]], entities[i])
            end
        end
    end

    # Infect initial turtles: ask n-of initial_infected turtles [become-infected]
    shuffled = copy(entities)
    Random.shuffle!(rng, shuffled)
    for i in 1:params.initial_infected
        state, timer = get_components(world, shuffled[i], (VirusState, VirusTimer))
        state.status = VInfected
        timer.timer = 0
    end

    # Initial counts
    stats.num_susceptible = params.number_people - params.initial_infected
    stats.num_infected = params.initial_infected
    stats.num_resistant = 0
    return nothing
end

# --- Spread and Recovery (combined per NetLogo semantics) ---
# NetLogo: ask turtles with [infected?] [
#   ask link-neighbors with [not resistant? and not infected?] [
#     if random-float 1.0 < 0.10 [ become-infected ]
#   ]
#   set virus-timer virus-timer + 1
#   if virus-timer > 10 [
#     ifelse random-float 1.0 < 0.25 [ become-resistant ] [ become-susceptible ]
#   ]
# ]

struct VirusSpreadSystem <: System
    infected_snapshot::Vector{Entity}
end
VirusSpreadSystem() = VirusSpreadSystem(Entity[])

function update!(system::VirusSpreadSystem, world::World)
    params = get_resource(world, VirusParams)
    rng = get_resource(world, RNGResource).rng
    network = get_resource(world, VirusNetwork)

    # Snapshot currently infected entities (NetLogo fixes agentset at ask start)
    empty!(system.infected_snapshot)
    for (eids, states) in Query(world, (VirusState,))
        @inbounds for i in eachindex(states)
            if states[i].status == VInfected
                push!(system.infected_snapshot, eids[i])
            end
        end
    end

    # NetLogo ask shuffles the agentset
    Random.shuffle!(rng, system.infected_snapshot)

    # Process each infected entity
    for eid in system.infected_snapshot
        state, timer = get_components(world, eid, (VirusState, VirusTimer))

        # 1. Spread to susceptible link-neighbors
        neighbors = get(network.neighbors, eid, Entity[])
        for neighbor in neighbors
            nstate, ntimer = get_components(world, neighbor, (VirusState, VirusTimer))
            if nstate.status == VSusceptible
                if rand(rng) < params.virus_spread_chance
                    nstate.status = VInfected
                    ntimer.timer = 0
                end
            end
        end

        # 2. Increment virus timer
        timer.timer += 1

        # 3. Check recovery (timer > virus_check_freq)
        if timer.timer > params.virus_check_freq
            if rand(rng) < params.recovery_chance
                state.status = VResistant
            else
                state.status = VSusceptible
            end
            timer.timer = 0
        end
    end
    return nothing
end

# --- Resistance Loss ---
# NetLogo: ask turtles with [resistant?] [
#   if random-float 1.0 < 0.01 [ become-susceptible ]
# ]

struct VirusResistanceSystem <: System end

function update!(::VirusResistanceSystem, world::World)
    params = get_resource(world, VirusParams)
    rng = get_resource(world, RNGResource).rng

    for (_, states, timers) in Query(world, (VirusState, VirusTimer))
        @inbounds for i in eachindex(states)
            if states[i].status == VResistant
                if rand(rng) < params.lose_immunity_chance
                    states[i].status = VSusceptible
                    timers[i].timer = 0
                end
            end
        end
    end
    return nothing
end

# --- Statistics ---
# NetLogo: update-counts

struct VirusStatsSystem <: System end

function update!(::VirusStatsSystem, world::World)
    stats = get_resource(world, VirusStats)
    ns = 0; ni = 0; nr = 0

    for (_, states) in Query(world, (VirusState,))
        @inbounds for i in eachindex(states)
            s = states[i].status
            if s == VSusceptible
                ns += 1
            elseif s == VInfected
                ni += 1
            else
                nr += 1
            end
        end
    end

    stats.num_susceptible = ns
    stats.num_infected = ni
    stats.num_resistant = nr
    return nothing
end

# --- Termination ---
# NetLogo: if num-infected = 0 [ stop ]

struct VirusTerminationSystem <: System end

function update!(::VirusTerminationSystem, world::World)
    params = get_resource(world, VirusParams)
    tick = get_resource(world, Tick)
    stats = get_resource(world, VirusStats)
    if stats.num_infected == 0 || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
