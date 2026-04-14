# Spreading Groups – ECS systems
# Build BA network, select spreading group, seed infection, run epidemic

struct InitSGroupSystem <: System end

# Eigenvector centrality via power iteration (matches NetLogo nw:eigenvector-centrality)
function _sgroup_eigenvector_centrality(net::SGroupNetwork)
    n = net.n_agents
    x = ones(n) / n
    for _ in 1:100
        new_x = zeros(n)
        for i in 1:n
            for j in net.adj[i]
                new_x[i] += x[j]
            end
        end
        nrm = sqrt(sum(v^2 for v in new_x))
        if nrm > 0
            new_x ./= nrm
        end
        x = new_x
    end
    return x
end

# Add a single node via preferential attachment (NetLogo create-preferential-net)
function _sgroup_add_ba_node!(net::SGroupNetwork, rng, m::Int, gamma::Float64)
    new_id = _sgroup_add_agent!(net)
    total_degree = sum(net.degree[k] for k in 1:(new_id - 1))
    targets = Set{Int}()
    attempts = 0
    while length(targets) < m && attempts < 10_000
        attempts += 1
        if rand(rng) < gamma && total_degree > 0
            r = rand(rng) * total_degree
            cumulative = 0.0
            for j in 1:(new_id - 1)
                cumulative += net.degree[j]
                if cumulative >= r
                    push!(targets, j)
                    break
                end
            end
        else
            push!(targets, rand(rng, 1:(new_id - 1)))
        end
    end
    for t in targets
        _sgroup_add_edge!(net, new_id, t)
    end
    return new_id
end

function initialize!(::InitSGroupSystem, world::World)
    params = get_resource(world, SGroupParams)
    rng    = get_resource(world, RNGResource).rng
    net    = get_resource(world, SGroupNetwork)
    stats  = get_resource(world, SGroupStats)

    # Phase 1: Build initial ring of 5 nodes (NetLogo: chain + closing edge)
    for _ in 1:5
        _sgroup_add_agent!(net)
    end
    # NetLogo builds: 1-2, 2-3, 3-4, 4-5, then 5-1 (ring)
    for i in 1:4
        _sgroup_add_edge!(net, i, i + 1)
    end
    _sgroup_add_edge!(net, 5, 1)

    # Phase 2: Add num_nodes/2 nodes via BA (= 50 nodes → total 55)
    n_phase2 = params.num_nodes ÷ 2
    for _ in 1:n_phase2
        _sgroup_add_ba_node!(net, rng, params.m, params.gamma)
    end

    # Phase 3: Select spreading group from current nodes (55)
    n_current = net.n_agents
    n_group = max(1, round(Int, params.num_nodes * params.spreading_group_percent / 100.0))
    indices = Random.shuffle(rng, collect(1:n_current))
    group_members = indices[1:min(n_group, n_current)]
    for i in group_members
        net.spreading_group[i] = true
    end

    # Stochastic partial connection (NetLogo: repeat spreadingGroupRepet [create-spreading-group])
    # Each spreading-group member picks two random members and connects them if not already linked
    spreading_group_repet = 2
    for _ in 1:spreading_group_repet
        sg = findall(net.spreading_group[1:n_current])
        # NetLogo: ask spreading-group [...] — shuffled
        perm = Random.shuffle(rng, copy(sg))
        for _ in perm
            a = sg[rand(rng, 1:length(sg))]
            b = sg[rand(rng, 1:length(sg))]
            if a != b
                _sgroup_add_edge!(net, a, b)  # no-op if already connected
            end
        end
    end

    # Phase 4: Add remaining nodes via BA (num_nodes/2 - 4 = 46 nodes → total 101)
    n_phase4 = params.num_nodes ÷ 2 - 4
    for _ in 1:n_phase4
        _sgroup_add_ba_node!(net, rng, params.m, params.gamma)
    end

    # Phase 5: Seed initial infected via eigenvector centrality (NetLogo: nw:eigenvector-centrality)
    # NetLogo reinfect-once: resets all sizes to 1, then sets infected nodes to size 2
    ec = _sgroup_eigenvector_centrality(net)
    ec_order = sortperm(ec; rev = true)
    for k in 1:min(params.num_infected_init, net.n_agents)
        net.infected[ec_order[k]] = true
        net.agent_size[ec_order[k]] = 2.0   # NetLogo: set size 2
    end
    # num_infected is cumulative (matches NetLogo global that only increments)
    stats.num_infected = params.num_infected_init
    stats.prev_infected_count = 0
    return nothing
end

# --- Main go procedure (single system to preserve NetLogo ordering) ---

struct SGroupGoSystem <: System end

function update!(::SGroupGoSystem, world::World)
    params = get_resource(world, SGroupParams)
    rng    = get_resource(world, RNGResource).rng
    net    = get_resource(world, SGroupNetwork)
    stats  = get_resource(world, SGroupStats)

    # 1. If all infected → stop
    n_currently_infected = count(net.infected[1:net.n_agents])
    if n_currently_infected == net.n_agents
        get_resource(world, Terminate).stop = true
        return nothing
    end

    # 2. Spreading: infected nodes try to infect uninfected neighbours
    # NetLogo: ask turtles with [infected? = true] — shuffled
    infected_list = findall(net.infected[1:net.n_agents])
    Random.shuffle!(rng, infected_list)
    for i in infected_list
        # NetLogo: ask link-neighbors with [infected? = false] — snapshot + shuffled
        uninfected_nbrs = [j for j in net.adj[i] if !net.infected[j]]
        Random.shuffle!(rng, uninfected_nbrs)
        for j in uninfected_nbrs
            prob = params.retention_loss ? params.p * net.agent_size[i] : params.p
            if rand(rng) <= prob
                net.infected[j] = true
                stats.num_infected += 1   # cumulative (matches NetLogo)
            end
        end
    end

    # 3. Stalling check: compare current infected count with post-infection count
    #    from previous tick (NetLogo: tmp vs previous-num-infected, both post-infection)
    current_infected = count(net.infected[1:net.n_agents])
    if current_infected == stats.prev_infected_count
        get_resource(world, Terminate).stop = true
        return nothing
    end
    stats.prev_infected_count = current_infected

    # 4. Size decay for ALL agents (NetLogo: ask turtles [...])
    for i in 1:net.n_agents
        net.agent_size[i] /= params.size_reduction
        if net.agent_size[i] < 0.1
            net.infected[i] = false
        end
    end
    return nothing
end

# --- Tick-limit termination ---

struct SGroupTerminationSystem <: System end

function update!(::SGroupTerminationSystem, world::World)
    params = get_resource(world, SGroupParams)
    tick   = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
