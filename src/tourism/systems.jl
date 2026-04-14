struct InitTourismSystem <: System end

function initialize!(::InitTourismSystem, world::World)
    params = get_resource(world, TourismParams)
    rng = get_resource(world, RNGResource).rng
    stats = get_resource(world, TourismStats)
    state = get_resource(world, TourismState)

    stats.attendance = 0
    stats.reputation = 0.0
    state.attraction = 300.0

    # Pass 1: Create all visitors with revisit_interval (NetLogo: crt block)
    eids = Entity[]
    for _ in 1:params.initial_number
        e = new_entity!(world, (TourismVisitor(
            rand(rng, 1:9), 0, false, false
        ),))
        push!(eids, e)
    end

    # Pass 2: Assign social? separately (NetLogo: ask turtles [...])
    for e in eids
        v = get_components(world, e, (TourismVisitor,))[1]
        v.is_social = rand(rng) < 0.5
    end
end

struct TourismUpdateSystem <: System end

function update!(::TourismUpdateSystem, world::World)
    params = get_resource(world, TourismParams)
    rng = get_resource(world, RNGResource).rng
    tick = get_resource(world, Tick)
    stats = get_resource(world, TourismStats)
    state = get_resource(world, TourismState)

    all_eids = Entity[]
    for (eids,) in Query(world, (TourismVisitor,))
        append!(all_eids, eids)
    end
    isempty(all_eids) && return

    # NetLogo: tick happens at START of go, before the ask block
    current_tick = tick.tick + 1

    shuffle!(rng, all_eids)
    to_spawn = TourismVisitor[]
    to_kill = Set{Entity}()

    for eid in all_eids
        eid in to_kill && continue

        visitor = get_components(world, eid, (TourismVisitor,))[1]
        visitor.revisit_interval -= 1

        if visitor.revisit_interval == 0
            visitor.at_destination = true
            evaluate_visitor!(visitor, state, stats, params, rng, to_spawn, to_kill, eid, world, all_eids)

            # Update attraction (only if visitor survived evaluate)
            if params.innovative
                if current_tick <= 30
                    state.attraction += -1.0 + params.maintaining_rate / 100.0 + 0.2
                else
                    state.attraction += -1.0 + params.maintaining_rate / 100.0 + 0.2 + 0.1
                end
            else
                state.attraction += -1.0 + params.maintaining_rate / 100.0 + 0.2
            end

            # Promotive: hatch new visitor
            if params.promotive && !(eid in to_kill)
                push!(to_spawn, TourismVisitor(
                    rand(rng, 1:9), 0, rand(rng) < 0.5, false
                ))
            end
        else
            visitor.at_destination = false
        end

        # Recount attendance (NetLogo: count turtles-on destination-patches)
        dest_count = 0
        for (eids2, visitors2) in Query(world, (TourismVisitor,))
            @inbounds for j in eachindex(visitors2)
                if visitors2[j].at_destination && !(eids2[j] in to_kill)
                    dest_count += 1
                end
            end
        end
        stats.attendance = dest_count

        # Death check: if 1 = random 9 + 1 → probability 1/9
        if !(eid in to_kill) && rand(rng, 1:9) == 1
            push!(to_kill, eid)
        end
    end

    # Extension check
    if params.extension && current_tick == 70
        params.capacity += 100
    end

    for eid in to_kill
        is_alive(world, eid) && remove_entity!(world, eid)
    end
    for v in to_spawn
        new_entity!(world, (v,))
    end
end

function evaluate_visitor!(visitor, state, stats, params, rng, to_spawn, to_kill, eid, world, all_eids)
    attraction = state.attraction
    attendance = Float64(stats.attendance)
    capacity = Float64(params.capacity)
    died = false

    # NetLogo uses sequential `if` (not if/elseif). Conditions can overlap at
    # boundary values, so we use separate `if` blocks with a `died` guard.
    if visitor.is_social
        if attraction >= 250 && attendance <= 0.5 * capacity
            visitor.evaluation = 3
            stats.reputation += 2
            visitor.revisit_interval = rand(rng, 0:3)
            for _ in 1:2
                push!(to_spawn, TourismVisitor(rand(rng, 1:9), 0, true, false))
            end
        end
        if attraction >= 250 && attendance > 0.5 * capacity && attendance < capacity
            visitor.evaluation = 2
            stats.reputation += 1
            visitor.revisit_interval = rand(rng, 0:7)
            push!(to_spawn, TourismVisitor(rand(rng, 1:9), 0, true, false))
        end
        if attraction <= 250 && attraction > 50 && attendance <= 0.5 * capacity
            visitor.evaluation = 1
            visitor.revisit_interval = rand(rng, 0:29)
        end
        if attraction <= 250 && attraction > 50 && attendance > 0.5 * capacity && attendance < capacity
            visitor.evaluation = 1
            visitor.revisit_interval = rand(rng, 0:29)
        end
        if attendance >= capacity && !died
            visitor.evaluation = 0
            stats.reputation -= 2
            push!(to_kill, eid)
            died = true
            kill_one_of_type!(world, true, to_kill, all_eids, rng)
        end
        if attraction <= 50 && !died
            visitor.evaluation = 0
            stats.reputation -= 2
            push!(to_kill, eid)
            died = true
            kill_one_of_type!(world, true, to_kill, all_eids, rng)
        end
    else
        if attraction >= 250 && attendance <= 0.5 * capacity
            visitor.evaluation = 3
            stats.reputation += 2
            visitor.revisit_interval = rand(rng, 0:3)
            for _ in 1:2
                push!(to_spawn, TourismVisitor(rand(rng, 1:9), 0, false, false))
            end
        end
        if attraction >= 250 && attendance > 0.5 * capacity && attendance < 0.8 * capacity
            visitor.evaluation = 1
            visitor.revisit_interval = rand(rng, 0:29)
        end
        if attendance >= 0.8 * capacity && !died
            visitor.evaluation = 0
            stats.reputation -= 2
            push!(to_kill, eid)
            died = true
            kill_one_of_type!(world, false, to_kill, all_eids, rng)
        end
        if attraction <= 250 && attraction > 0 && attendance <= 0.5 * capacity
            visitor.evaluation = 2
            stats.reputation += 1
            visitor.revisit_interval = rand(rng, 0:7)
            push!(to_spawn, TourismVisitor(rand(rng, 1:9), 0, false, false))
        end
        if attraction <= 250 && attendance > 0.5 * capacity && attraction > 0 && attendance < 0.8 * capacity
            visitor.evaluation = 1
            visitor.revisit_interval = rand(rng, 0:29)
        end
        if attraction <= 0 && !died
            visitor.evaluation = 0
            stats.reputation -= 2
            push!(to_kill, eid)
            died = true
            kill_one_of_type!(world, false, to_kill, all_eids, rng)
        end
    end
end

function kill_one_of_type!(world, is_social::Bool, to_kill, all_eids, rng)
    candidates = Entity[]
    for e in all_eids
        e in to_kill && continue
        is_alive(world, e) || continue
        v = get_components(world, e, (TourismVisitor,))[1]
        if v.is_social == is_social
            push!(candidates, e)
        end
    end
    if !isempty(candidates)
        push!(to_kill, candidates[rand(rng, 1:length(candidates))])
    end
end

struct TourismStatsSystem <: System end

function update!(::TourismStatsSystem, world::World)
    stats = get_resource(world, TourismStats)
    dest_count = 0
    for (_, visitors) in Query(world, (TourismVisitor,))
        for v in visitors
            if v.at_destination
                dest_count += 1
            end
        end
    end
    stats.attendance = dest_count
end

struct TourismTerminationSystem <: System end

function update!(::TourismTerminationSystem, world::World)
    params = get_resource(world, TourismParams)
    tick = get_resource(world, Tick)
    term = get_resource(world, Terminate)

    n_visitors = 0
    for (eids,) in Query(world, (TourismVisitor,))
        n_visitors += length(eids)
    end
    if n_visitors == 0
        term.stop = true
        return
    end

    if tick.tick + 1 >= params.max_ticks
        term.stop = true
    end
end
