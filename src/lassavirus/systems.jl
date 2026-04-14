# Lassa Virus – ECS systems matching the NetLogo reference.
# Execution order: init → movement → infection+progression → stats → termination
#
# NetLogo model uses color to track disease states. Two breeds: rats and humans.
# Rats just move and carry infection. Humans have full disease progression.

# --- Initialization ---

struct InitLassaSystem <: System end

function initialize!(::InitLassaSystem, world::World)
    params = get_resource(world, LassaParams)
    rng = get_resource(world, RNGResource).rng
    registry = get_resource(world, LassaRegistry)
    stats = get_resource(world, LassaStats)
    wspan = params.world_max - params.world_min + 1  # 33
    w = Float64(wspan)

    pct_Mild_Cases = 100 - params.pct_Severe_Cases
    initial_mild = (params.Initial_Number_Of_Cases * pct_Mild_Cases) / 100
    initial_severe = (params.Initial_Number_Of_Cases * params.pct_Severe_Cases) / 100

    # Create rats
    empty!(registry.rat_entities)
    for _ in 1:params.Multimammate_Rat_Population
        # random-xcor gives float in [-16.5, 16.5) → offset to [0, 33)
        x = rand(rng) * w
        y = rand(rng) * w
        e = new_entity!(world, (
            LassaPosition(x, y),
            LassaHeading(Float64(rand(rng, 0:359))),
            RatTag(true),
        ))
        push!(registry.rat_entities, e)
    end

    # Create humans
    empty!(registry.human_entities)
    for _ in 1:params.Human_Population
        x = rand(rng) * w
        y = rand(rng) * w
        e = new_entity!(world, (
            LassaPosition(x, y),
            LassaHeading(Float64(rand(rng, 0:359))),
            HumanState(LassaSusceptible, 0, Float64(1)),  # control_speed = 1
        ))
        push!(registry.human_entities, e)
    end

    # Initial cases: ask n-of initial_mild_cases Humans [set color orange+2]
    shuffled = copy(registry.human_entities)
    Random.shuffle!(rng, shuffled)
    mild_count = round(Int, initial_mild)
    severe_count = round(Int, initial_severe)
    for i in 1:mild_count
        hs = get_components(world, shuffled[i], (HumanState,))[1]
        hs.status = LassaMild
    end
    for i in (mild_count+1):(mild_count+severe_count)
        hs = get_components(world, shuffled[i], (HumanState,))[1]
        hs.status = LassaSevere
    end

    # Initialize stats running totals
    stats.mild_cases = 0
    stats.severe_cases = 0
    stats.fatalities = 0
    stats.infected_not_infectious = 0
    stats.mild_cases_count = mild_count
    stats.severe_cases_count = severe_count
    stats.immune_infectious = 0
    stats.immune_not_infectious = 0
    stats.total_immune = 0
    stats.current_cases = mild_count + severe_count
    stats.total_mild_cases = Float64(initial_mild)
    stats.total_severe_cases = Float64(initial_severe)
    stats.total_cases = initial_mild + initial_severe
    stats.total_infectious = mild_count + severe_count
    stats.total_fatalities = 0
    stats.total_infected = Float64(stats.infected_not_infectious + stats.total_infectious + stats.total_fatalities)
    stats.pct_infected = (stats.total_infected / params.Human_Population) * 100
    stats.pct_uninfected = 100.0 - stats.pct_infected
    stats.pct_immune = 0.0
    stats.average_pct_CFR = 0.0
    return nothing
end

# --- Movement ---
# NetLogo: rats fd control_speed * -1 * ((1/HBF)*0.01); rt random 100; lt random 100
#          humans fd human_speed * ((1/HBF)*0.01); rt random 45; lt random 45; hours += 1

struct LassaMovementSystem <: System end

function _lassa_wrap!(pos::LassaPosition, w::Float64)
    pos.x = mod(pos.x, w)
    pos.y = mod(pos.y, w)
    return nothing
end

function _lassa_fd!(pos::LassaPosition, heading::LassaHeading, dist::Float64, w::Float64)
    rad = heading.angle * π / 180.0
    pos.x += sin(rad) * dist
    pos.y += cos(rad) * dist
    _lassa_wrap!(pos, w)
    return nothing
end

function update!(::LassaMovementSystem, world::World)
    params = get_resource(world, LassaParams)
    rng = get_resource(world, RNGResource).rng
    registry = get_resource(world, LassaRegistry)
    wspan = params.world_max - params.world_min + 1
    w = Float64(wspan)
    control_speed = 1.0

    # ask rats [fd ...; rt random 100; lt random 100]
    rat_order = randperm(rng, length(registry.rat_entities))
    for ri in rat_order
        re = registry.rat_entities[ri]
        rpos, rhead = get_components(world, re, (LassaPosition, LassaHeading))
        dist = control_speed * -1.0 * ((1.0 / params.Human_Behaviour_Factor) * 0.01)
        _lassa_fd!(rpos, rhead, dist, w)
        rhead.angle += rand(rng, 0:99) - rand(rng, 0:99)
        rhead.angle = mod(rhead.angle, 360.0)
    end

    # ask humans [fd ...; rt random 45; lt random 45; set hours hours + 1]
    human_order = randperm(rng, length(registry.human_entities))
    for hi in human_order
        he = registry.human_entities[hi]
        hpos, hhead, hstate = get_components(world, he, (LassaPosition, LassaHeading, HumanState))
        dist = hstate.human_speed * ((1.0 / params.Human_Behaviour_Factor) * 0.01)
        _lassa_fd!(hpos, hhead, dist, w)
        hhead.angle += rand(rng, 0:44) - rand(rng, 0:44)
        hhead.angle = mod(hhead.angle, 360.0)
        hstate.hours += 1
    end
    return nothing
end

# --- Infection and Disease Progression ---
# This is the big combined system matching the NetLogo `ask humans [...]` block.
# Each human is processed in random order. Infection checks use "here" (same patch).

struct LassaInfectionSystem <: System end

# Check if two positions are on the same patch (same rounded coords)
function _lassa_same_patch(p1::LassaPosition, p2::LassaPosition, min_coord::Int)
    return round(Int, p1.x + min_coord) == round(Int, p2.x + min_coord) &&
           round(Int, p1.y + min_coord) == round(Int, p2.y + min_coord)
end

function update!(::LassaInfectionSystem, world::World)
    params = get_resource(world, LassaParams)
    rng = get_resource(world, RNGResource).rng
    registry = get_resource(world, LassaRegistry)
    stats = get_resource(world, LassaStats)
    immune_or_severe_pct = params.pct_Infectiousness_H2H * (1.0 - params.Human_Behaviour_Factor)

    n_humans = length(registry.human_entities)
    n_rats = length(registry.rat_entities)

    # ask humans (random order)
    human_order = randperm(rng, n_humans)

    for hi in human_order
        he = registry.human_entities[hi]
        hpos, hstate = get_components(world, he, (LassaPosition, HumanState))

        # --- Infection spreading ---
        # Mild cases infect other humans-here
        if hstate.status == LassaMild
            # ask other humans-here
            for hj in 1:n_humans
                hj == hi && continue
                he2 = registry.human_entities[hj]
                hpos2, hstate2 = get_components(world, he2, (LassaPosition, HumanState))
                if _lassa_same_patch(hpos, hpos2, params.world_min)
                    # random 100 < pct_Infectiousness_H2H  (integer random)
                    if rand(rng, 0:99) < params.pct_Infectiousness_H2H
                        if hstate2.status == LassaSusceptible
                            hstate2.status = LassaIncubating
                            hstate2.hours = 0
                        end
                    end
                end
            end
        else
            # Rats infect humans-here
            # NetLogo: ask rats [ask other humans-here [...]]
            for ri in 1:n_rats
                re = registry.rat_entities[ri]
                rpos = get_components(world, re, (LassaPosition,))[1]
                # Check if this human is at same patch as this rat
                if _lassa_same_patch(hpos, rpos, params.world_min)
                    # random-float 100 < pct_Infectiousness_R2H
                    if rand(rng) * 100.0 < params.pct_Infectiousness_R2H
                        if hstate.status == LassaSusceptible
                            hstate.status = LassaIncubating
                            hstate.hours = 0
                        end
                    end
                end
            end
        end

        # Immune-infectious or severe infect others
        if hstate.status == LassaImmuneInfectious || hstate.status == LassaSevere
            for hj in 1:n_humans
                hj == hi && continue
                he2 = registry.human_entities[hj]
                hpos2, hstate2 = get_components(world, he2, (LassaPosition, HumanState))
                if _lassa_same_patch(hpos, hpos2, params.world_min)
                    if rand(rng) * 100.0 < immune_or_severe_pct
                        if hstate2.status == LassaSusceptible
                            hstate2.status = LassaIncubating
                            hstate2.hours = 0
                        end
                    end
                end
            end
        end

        # --- Disease Progression ---
        # Incubating → Mild or Severe
        if hstate.status == LassaIncubating && hstate.hours > (params.Incubation_Period * 24)
            if rand(rng) * 100.0 < params.pct_Severe_Cases
                hstate.status = LassaSevere
                stats.severe_cases += 1
                hstate.hours = 0
                hstate.human_speed = 0.0
            else
                hstate.status = LassaMild
                stats.mild_cases += 1
                hstate.hours = 0
                hstate.human_speed = 0.5
            end
        end

        # Mild → Dead or Immune-Infectious
        if hstate.status == LassaMild && hstate.hours == (params.Sick_Days * 24)
            if rand(rng) * 100.0 < params.CFR_Mild_Case
                hstate.status = LassaDead
                stats.fatalities += 1
                hstate.hours = 0
                hstate.human_speed = 0.0
            else
                hstate.status = LassaImmuneInfectious
                hstate.hours = 0
                hstate.human_speed = 0.5
            end
        end

        # Severe → Dead or Immune-Infectious
        if hstate.status == LassaSevere && hstate.hours == (params.Sick_Days * 24)
            if rand(rng) * 100.0 < params.CFR_Severe_Case
                hstate.status = LassaDead
                stats.fatalities += 1
                hstate.hours = 0
                hstate.human_speed = 0.0
            else
                hstate.status = LassaImmuneInfectious
                hstate.hours = 0
                hstate.human_speed = 1.0  # control_speed
            end
        end

        # Immune-Infectious → Immune
        if hstate.status == LassaImmuneInfectious && hstate.hours == (params.Infectious_Days_After_Recovery * 24)
            hstate.status = LassaImmune
            hstate.hours = 0
            hstate.human_speed = 1.0  # control_speed
        end
    end
    return nothing
end

# --- Statistics ---
# Compute all tracked globals matching NetLogo

struct LassaStatsSystem <: System end

function update!(::LassaStatsSystem, world::World)
    params = get_resource(world, LassaParams)
    registry = get_resource(world, LassaRegistry)
    stats = get_resource(world, LassaStats)

    pct_Mild_Cases = 100 - params.pct_Severe_Cases
    initial_mild = (params.Initial_Number_Of_Cases * pct_Mild_Cases) / 100.0
    initial_severe = (params.Initial_Number_Of_Cases * params.pct_Severe_Cases) / 100.0

    n_incubating = 0
    n_mild = 0
    n_severe = 0
    n_immune_inf = 0
    n_immune = 0
    n_susceptible = 0
    n_dead = 0

    for he in registry.human_entities
        hs = get_components(world, he, (HumanState,))[1]
        s = hs.status
        if s == LassaSusceptible
            n_susceptible += 1
        elseif s == LassaIncubating
            n_incubating += 1
        elseif s == LassaMild
            n_mild += 1
        elseif s == LassaSevere
            n_severe += 1
        elseif s == LassaImmuneInfectious
            n_immune_inf += 1
        elseif s == LassaImmune
            n_immune += 1
        elseif s == LassaDead
            n_dead += 1
        end
    end

    stats.infected_not_infectious = n_incubating
    stats.mild_cases_count = n_mild
    stats.severe_cases_count = n_severe
    stats.immune_infectious = n_immune_inf
    stats.immune_not_infectious = n_immune
    stats.total_immune = n_immune_inf + n_immune
    stats.current_cases = n_mild + n_severe
    stats.total_mild_cases = stats.mild_cases + initial_mild
    stats.total_severe_cases = stats.severe_cases + initial_severe
    stats.total_cases = stats.total_mild_cases + stats.total_severe_cases
    stats.total_infectious = stats.current_cases + n_immune_inf
    stats.total_fatalities = n_dead  # count humans with [color = gray]
    stats.total_infected = Float64(stats.infected_not_infectious + stats.total_infectious + stats.total_fatalities)
    if stats.total_cases > 0
        stats.average_pct_CFR = (stats.fatalities / stats.total_cases) * 100.0
    else
        stats.average_pct_CFR = 0.0
    end
    stats.pct_infected = (stats.total_infected / params.Human_Population) * 100.0
    stats.pct_uninfected = (n_susceptible / params.Human_Population) * 100.0
    stats.pct_immune = (stats.total_immune / params.Human_Population) * 100.0
    return nothing
end

# --- Termination ---
# NetLogo: if infected_not_infectious + current_cases + count humans with [color = white] = 0 [stop]

struct LassaTerminationSystem <: System end

function update!(::LassaTerminationSystem, world::World)
    params = get_resource(world, LassaParams)
    tick = get_resource(world, Tick)
    stats = get_resource(world, LassaStats)

    # Count susceptible humans
    n_susceptible = 0
    registry = get_resource(world, LassaRegistry)
    for he in registry.human_entities
        hs = get_components(world, he, (HumanState,))[1]
        if hs.status == LassaSusceptible
            n_susceptible += 1
        end
    end

    if (stats.infected_not_infectious + stats.current_cases + n_susceptible == 0) ||
       tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
