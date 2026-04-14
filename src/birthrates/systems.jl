# Birth Rates Model Systems
# Execution order: init → reproduce → grim-reaper → stats → termination
# NetLogo go: reproduce; grim-reaper; update-counts; tick

# --- Initialization ---
# NetLogo: create-turtles carrying-capacity [setxy random-xcor random-ycor;
#   ifelse who < (carrying-capacity / 2) [set color blue] [set color red]]
# Heading: random integer [0,359] from create-turtles

struct InitBirthRatesSystem <: System end

function initialize!(::InitBirthRatesSystem, world::World)
    params = get_resource(world, BirthRatesParams)
    rng = get_resource(world, RNGResource).rng
    stats = get_resource(world, BirthRatesStats)
    wf = Float64(params.grid_width)
    hf = Float64(params.grid_height)
    half = div(params.carrying_capacity, 2)

    for i in 1:params.carrying_capacity
        x = rand(rng) * wf
        y = rand(rng) * hf
        heading = Float64(rand(rng, 0:359))
        if i <= half
            new_entity!(world, (BRPosition(x, y), BRHeading(heading), BlueTurtle()))
        else
            new_entity!(world, (BRPosition(x, y), BRHeading(heading), RedTurtle()))
        end
    end

    stats.blue_count = half
    stats.red_count = params.carrying_capacity - half
    return nothing
end

# --- Reproduction ---
# NetLogo: ask turtles [
#   set fertility floor <breed>-fertility
#   set fertility-remainder <breed>-fertility - floor <breed>-fertility
#   ifelse (random-float 100) < (100 * fertility-remainder)
#     [ hatch fertility + 1 [ wander ] ]
#     [ hatch fertility     [ wander ] ]
# ]
# wander: rt random-float 30 - random-float 30; fd 1
# Two separate random-float 30 calls → triangular distribution on [-30,30)
# Offspring inherit parent position + heading, then wander independently.
# World is locked during Query; collect spawns, apply after.

mutable struct BRReproduceSystem <: System
    spawns::Vector{Tuple{Float64, Float64, Float64, Bool}}  # x, y, heading, is_red
end
BRReproduceSystem() = BRReproduceSystem(Tuple{Float64,Float64,Float64,Bool}[])

function update!(system::BRReproduceSystem, world::World)
    params = get_resource(world, BirthRatesParams)
    rng = get_resource(world, RNGResource).rng
    wf = Float64(params.grid_width)
    hf = Float64(params.grid_height)

    empty!(system.spawns)

    # Red turtles reproduce
    red_base = floor(Int, params.red_fertility)
    red_rem = params.red_fertility - red_base
    for (_, positions, headings) in Query(world, (BRPosition, BRHeading); with=(RedTurtle,))
        @inbounds for i in eachindex(positions)
            num = if rand(rng) * 100.0 < 100.0 * red_rem
                red_base + 1
            else
                red_base
            end
            px, py, ph = positions[i].x, positions[i].y, headings[i].angle
            for _ in 1:num
                turn = rand(rng) * 30.0 - rand(rng) * 30.0
                new_heading = ph + turn
                θ = deg2rad(new_heading)
                nx = mod(px + sin(θ), wf)
                ny = mod(py + cos(θ), hf)
                push!(system.spawns, (nx, ny, new_heading, true))
            end
        end
    end

    # Blue turtles reproduce
    blue_base = floor(Int, params.blue_fertility)
    blue_rem = params.blue_fertility - blue_base
    for (_, positions, headings) in Query(world, (BRPosition, BRHeading); with=(BlueTurtle,))
        @inbounds for i in eachindex(positions)
            num = if rand(rng) * 100.0 < 100.0 * blue_rem
                blue_base + 1
            else
                blue_base
            end
            px, py, ph = positions[i].x, positions[i].y, headings[i].angle
            for _ in 1:num
                turn = rand(rng) * 30.0 - rand(rng) * 30.0
                new_heading = ph + turn
                θ = deg2rad(new_heading)
                nx = mod(px + sin(θ), wf)
                ny = mod(py + cos(θ), hf)
                push!(system.spawns, (nx, ny, new_heading, false))
            end
        end
    end

    # Spawn all offspring after query iteration completes
    for (x, y, heading, is_red) in system.spawns
        if is_red
            new_entity!(world, (BRPosition(x, y), BRHeading(heading), RedTurtle()))
        else
            new_entity!(world, (BRPosition(x, y), BRHeading(heading), BlueTurtle()))
        end
    end
    return nothing
end

# --- Grim Reaper ---
# NetLogo: if count turtles > carrying-capacity [
#   let chance-to-die (num-turtles - carrying-capacity) / num-turtles
#   ask turtles [ if random-float 1.0 < chance-to-die [ die ] ]
# ]

struct BRGrimReaperSystem <: System end

function update!(::BRGrimReaperSystem, world::World)
    params = get_resource(world, BirthRatesParams)
    rng = get_resource(world, RNGResource).rng

    num_turtles = 0
    for (eids, _) in Query(world, (BRPosition,))
        num_turtles += length(eids)
    end

    num_turtles <= params.carrying_capacity && return nothing

    chance_to_die = (num_turtles - params.carrying_capacity) / num_turtles

    to_remove = Entity[]
    for (eids, _) in Query(world, (BRPosition,))
        @inbounds for i in eachindex(eids)
            if rand(rng) < chance_to_die
                push!(to_remove, eids[i])
            end
        end
    end

    for eid in to_remove
        is_alive(world, eid) && remove_entity!(world, eid)
    end
    return nothing
end

# --- Statistics ---
# NetLogo: update-counts

struct BRStatsSystem <: System end

function update!(::BRStatsSystem, world::World)
    stats = get_resource(world, BirthRatesStats)

    red = 0
    for (eids, _) in Query(world, (BRPosition,); with=(RedTurtle,))
        red += length(eids)
    end

    blue = 0
    for (eids, _) in Query(world, (BRPosition,); with=(BlueTurtle,))
        blue += length(eids)
    end

    stats.red_count = red
    stats.blue_count = blue
    return nothing
end

# --- Termination ---

struct BRTerminationSystem <: System end

function update!(::BRTerminationSystem, world::World)
    params = get_resource(world, BirthRatesParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
