struct InitAIDSSystem <: System end

function _aids_random_near(rng, center::Float64)
    s = 0.0
    for _ in 1:40
        s += rand(rng) * center
    end
    return s / 20.0
end

function initialize!(::InitAIDSSystem, world::World)
    params = get_resource(world, AIDSParams)
    rng = get_resource(world, RNGResource).rng

    for i in 1:params.initial_people
        x = rand(rng) * params.grid_width
        y = rand(rng) * params.grid_height
        is_righty = rand(rng, Bool)
        infected = (i <= round(Int, params.initial_people * 0.025))
        inf_len = infected ? rand(rng) * params.symptoms_show : 0.0
        commitment = _aids_random_near(rng, params.average_commitment)
        ct = _aids_random_near(rng, params.average_coupling_tendency)
        cu = _aids_random_near(rng, params.average_condom_use)
        tf = _aids_random_near(rng, params.average_test_frequency)
        new_entity!(world, (AIDSPerson(x, y, infected, false, inf_len,
                                        false, 0, commitment, ct, cu, tf,
                                        is_righty, 0),))
    end

    _aids_update_stats!(world)
    return nothing
end

struct AIDSGoSystem <: System end

function update!(::AIDSGoSystem, world::World)
    params = get_resource(world, AIDSParams)
    rng = get_resource(world, RNGResource).rng

    # Collect all people
    people = Tuple{Entity, AIDSPerson}[]
    for (eids, persons) in Query(world, (AIDSPerson,))
        @inbounds for i in eachindex(persons)
            push!(people, (eids[i], persons[i]))
        end
    end

    # Build entity-to-index map
    eid_to_idx = Dict{Entity, Int}()
    for (i, (eid, _)) in enumerate(people)
        eid_to_idx[eid] = i
    end

    n = length(people)
    w = Float64(params.grid_width)
    h = Float64(params.grid_height)

    # Increment infection_length and couple_length
    indices = collect(1:n)
    Random.shuffle!(rng, indices)
    for i in indices
        p = people[i][2]
        if p.infected
            p.infection_length += 1.0
        end
        if p.coupled
            p.couple_length += 1
        end
    end

    # Move uncoupled people
    Random.shuffle!(rng, indices)
    for i in indices
        p = people[i][2]
        !p.coupled || continue
        heading = rand(rng) * 2π
        p.x = mod(p.x + sin(heading), w)
        p.y = mod(p.y + cos(heading), h)
    end

    # Coupling: righties initiate
    Random.shuffle!(rng, indices)
    for i in indices
        p = people[i][2]
        p.coupled && continue
        !p.is_righty && continue
        rand(rng) * 10.0 >= p.coupling_tendency && continue

        # Find a potential partner: uncoupled lefty nearby (within ~1 patch)
        best_j = 0
        best_dist = 2.0  # max coupling distance
        for j in 1:n
            j == i && continue
            q = people[j][2]
            q.coupled && continue
            q.is_righty && continue
            dx = abs(p.x - q.x); dx = min(dx, w - dx)
            dy = abs(p.y - q.y); dy = min(dy, h - dy)
            d = sqrt(dx^2 + dy^2)
            if d < best_dist
                best_dist = d
                best_j = j
            end
        end
        best_j == 0 && continue
        q = people[best_j][2]
        rand(rng) * 10.0 >= q.coupling_tendency && continue
        # Couple them
        p.coupled = true; q.coupled = true
        p.partner_idx = best_j; q.partner_idx = i
        p.couple_length = 0; q.couple_length = 0
    end

    # Uncouple
    Random.shuffle!(rng, indices)
    for i in indices
        p = people[i][2]
        !p.coupled && continue
        !p.is_righty && continue
        pi = p.partner_idx
        (pi < 1 || pi > n) && continue
        q = people[pi][2]
        if p.couple_length > p.commitment || q.couple_length > q.commitment
            p.coupled = false; q.coupled = false
            p.partner_idx = 0; q.partner_idx = 0
            p.couple_length = 0; q.couple_length = 0
        end
    end

    # Infect
    Random.shuffle!(rng, indices)
    for i in indices
        p = people[i][2]
        !p.coupled && continue
        !p.infected && continue
        p.known && continue
        pi = p.partner_idx
        (pi < 1 || pi > n) && continue
        q = people[pi][2]
        if rand(rng) * 11.0 > p.condom_use || rand(rng) * 11.0 > q.condom_use
            if rand(rng) * 100.0 < params.infection_chance
                q.infected = true
            end
        end
    end

    # Test
    Random.shuffle!(rng, indices)
    for i in indices
        p = people[i][2]
        if rand(rng) * 52.0 < p.test_frequency
            if p.infected
                p.known = true
            end
        end
        if p.infection_length > params.symptoms_show
            if rand(rng) * 100.0 < 5.0
                p.known = true
            end
        end
    end

    _aids_update_stats!(world)
    return nothing
end

function _aids_update_stats!(world::World)
    stats = get_resource(world, AIDSStats)
    nu = 0; niu = 0; nik = 0
    total = 0
    for (_, persons) in Query(world, (AIDSPerson,))
        @inbounds for i in eachindex(persons)
            p = persons[i]
            total += 1
            if !p.infected
                nu += 1
            elseif p.known
                nik += 1
            else
                niu += 1
            end
        end
    end
    stats.num_uninfected = nu
    stats.num_infected_unknown = niu
    stats.num_infected_known = nik
    stats.pct_infected = total > 0 ? (niu + nik) / total * 100.0 : 0.0
end

struct AIDSTerminationSystem <: System end

function update!(::AIDSTerminationSystem, world::World)
    params = get_resource(world, AIDSParams)
    stats = get_resource(world, AIDSStats)
    tick = get_resource(world, Tick)
    all_known = (stats.num_infected_unknown == 0 && stats.num_infected_known > 0)
    if all_known || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
