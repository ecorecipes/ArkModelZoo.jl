# SuperDiffuser — persuasion-based adoption on BA network

struct InitSDiffSystem <: System end

function _sdiff_build_ba!(net::SDiffNetwork, rng, n::Int, m::Int)
    # Start with m+1 fully connected nodes
    for _ in 1:(m+1)
        _sdiff_add_agent!(net)
    end
    for i in 1:(m+1), j in (i+1):(m+1)
        _sdiff_add_edge!(net, i, j)
    end
    # Preferential attachment for remaining nodes
    for _ in (m+2):n
        new_id = _sdiff_add_agent!(net)
        total_degree = sum(net.degree[1:new_id-1])
        targets = Set{Int}()
        attempts = 0
        while length(targets) < m && attempts < 10000
            attempts += 1
            r = rand(rng) * total_degree
            cumulative = 0.0
            for j in 1:(new_id-1)
                cumulative += net.degree[j]
                if cumulative >= r
                    push!(targets, j)
                    break
                end
            end
        end
        for t in targets
            _sdiff_add_edge!(net, new_id, t)
        end
    end
end

function initialize!(::InitSDiffSystem, world::World)
    params = get_resource(world, SDiffParams)
    rng    = get_resource(world, RNGResource).rng
    net    = get_resource(world, SDiffNetwork)
    stats  = get_resource(world, SDiffStats)

    _sdiff_build_ba!(net, rng, params.num_agents, params.min_links)

    # Assign agent properties
    for i in 1:net.n_agents
        # pers-one: random-normal(10, 20) clamped [0, 100]
        net.pers_one[i] = clamp(randn(rng) * 20.0 + params.avg_pers_one, 0.0, 100.0)
        # attitude: random-normal(2, 1) clamped [1, 3.9]
        net.attitude[i] = clamp(randn(rng) * 1.0 + params.avg_attitude, 1.0, 3.9)
        # pers-power: random-normal(0.25, 0.1) clamped [0, 2]
        net.pers_power[i] = clamp(randn(rng) * 0.1 + params.avg_pers_power, 0.0, 2.0)
        net.message[i] = 0.0
    end

    # Initial adopters: 5% of agents
    n_initial = max(1, round(Int, params.percent_adopted_start * params.num_agents))
    indices = shuffle!(rng, collect(1:net.n_agents))
    for k in 1:min(n_initial, net.n_agents)
        net.adopted[indices[k]] = true
    end

    stats.current_adopted = count(net.adopted)
    stats.status_quo_counter = 0
    return nothing
end

# --- Go system ---
struct SDiffGoSystem <: System end

function update!(::SDiffGoSystem, world::World)
    params = get_resource(world, SDiffParams)
    rng    = get_resource(world, RNGResource).rng
    net    = get_resource(world, SDiffNetwork)
    stats  = get_resource(world, SDiffStats)

    old_status_quo = stats.status_quo
    stats.status_quo = true

    # NetLogo does NOT clear messages at start of tick.
    # Messages persist if the target was processed BEFORE the persuader in the previous tick.
    # Non-adopted agents clear their own message in update-attitude after consuming it.

    # NetLogo: ask turtles [ update-friends; if adopted? [...] if not adopted? [...] ]
    # This is INTERLEAVED in shuffled order — each agent acts fully before the next.
    order = randperm(rng, net.n_agents)

    for i in order
        # update-friends: count adopted/non-adopted neighbors
        adopt_friends = 0
        non_adopt_friends = 0
        for j in net.adj[i]
            if net.adopted[j]
                adopt_friends += 1
            else
                non_adopt_friends += 1
            end
        end

        if net.adopted[i] && non_adopt_friends > 0
            # persuade
            if rand(rng, 0:99) < net.pers_one[i]
                # ask one-of link-neighbors with [adopted? = false]
                non_adopted_neighbors = Int[]
                for j in net.adj[i]
                    if !net.adopted[j]
                        push!(non_adopted_neighbors, j)
                    end
                end
                if !isempty(non_adopted_neighbors)
                    target = non_adopted_neighbors[rand(rng, 1:length(non_adopted_neighbors))]
                    net.message[target] = net.pers_power[i]
                end
            end
        end

        if !net.adopted[i]
            # update-attitude
            old_attitude = net.attitude[i]
            net.attitude[i] += net.message[i] + adopt_friends * params.social_influence
            if net.attitude[i] > 7.0
                net.attitude[i] = 7.0
            end
            if net.attitude[i] >= params.adopt_threshold
                net.adopted[i] = true
            end
            net.message[i] = 0.0
            if old_attitude != net.attitude[i]
                stats.status_quo = false
            end
        end
    end

    # Status-quo counter: NetLogo increments when BOTH previous and current tick had no attitude changes
    if old_status_quo && stats.status_quo
        stats.status_quo_counter += 1
    else
        stats.status_quo_counter = 0
    end

    stats.current_adopted = count(net.adopted)

    return nothing
end

# --- Termination ---
struct SDiffTerminationSystem <: System end

function update!(::SDiffTerminationSystem, world::World)
    params = get_resource(world, SDiffParams)
    tick   = get_resource(world, Tick)
    net    = get_resource(world, SDiffNetwork)
    stats  = get_resource(world, SDiffStats)

    all_adopted = all(net.adopted)
    if all_adopted || stats.status_quo_counter >= params.status_quo_limit || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
