# Spreading Bots — Bot-augmented epidemic diffusion on preferential-attachment network

struct InitSBotSystem <: System end

function _sbot_find_partner(net::SBotNetwork, rng, node::Int, gamma::Float64)
    while true
        if rand(rng) >= gamma && !isempty(net.degrees_bag)
            partner = net.degrees_bag[rand(rng, 1:length(net.degrees_bag))]
        else
            partner = rand(rng, 1:net.n_agents)
        end
        if partner != node && partner ∉ net.adj[node]
            return partner
        end
    end
end

function initialize!(::InitSBotSystem, world::World)
    params = get_resource(world, SBotParams)
    rng    = get_resource(world, RNGResource).rng
    net    = get_resource(world, SBotNetwork)
    stats  = get_resource(world, SBotStats)

    # Create initial ring of 5 nodes
    for _ in 1:5
        _sbot_add_agent!(net)
    end
    for i in 1:4
        _sbot_add_edge!(net, i, i + 1)
    end
    _sbot_add_edge!(net, 5, 1)

    # First half of preferential attachment growth
    half1 = div(params.num_nodes, 2)
    for _ in 1:half1
        id = _sbot_add_agent!(net)
        for _ in 1:params.m
            partner = _sbot_find_partner(net, rng, id, params.gamma)
            _sbot_add_edge!(net, id, partner)
        end
    end

    # Set bot group
    n_bots = max(1, div(net.n_agents * params.bot_group_percent, 100))
    bot_indices = shuffle!(rng, collect(1:net.n_agents))[1:n_bots]
    for i in bot_indices
        net.is_bot[i] = true
    end

    # Create bot-internal edges
    for _ in 1:params.bot_group_repet
        for i in bot_indices
            j = bot_indices[rand(rng, 1:length(bot_indices))]
            if i != j
                _sbot_add_edge!(net, i, j)
            end
        end
    end

    # Second half of preferential attachment growth
    half2 = div(params.num_nodes, 2) - 4
    for _ in 1:half2
        id = _sbot_add_agent!(net)
        for _ in 1:params.m
            partner = _sbot_find_partner(net, rng, id, params.gamma)
            _sbot_add_edge!(net, id, partner)
        end
    end

    # Seed initial infected using reinfect strategy
    _sbot_reinfect!(net, rng, params, stats)
    return nothing
end

function _sbot_reinfect!(net::SBotNetwork, rng, params::SBotParams, stats::SBotStats)
    for i in 1:net.n_agents
        net.infected[i] = false
        net.agent_size[i] = 1.0
    end
    stats.num_infected = params.num_infected_init
    stats.previous_num_infected = 0

    n_to_infect = min(params.num_infected_init, net.n_agents)

    if params.reinfect_type == "random"
        chosen = shuffle!(rng, collect(1:net.n_agents))[1:n_to_infect]
        for i in chosen
            net.infected[i] = true
            net.agent_size[i] = 2.0
        end
    elseif params.reinfect_type == "group"
        bot_ids = findall(net.is_bot)
        chosen = shuffle!(rng, copy(bot_ids))[1:min(n_to_infect, length(bot_ids))]
        for i in chosen
            net.infected[i] = true
            net.agent_size[i] = 2.0
        end
    elseif params.reinfect_type == "eigenval-centrality"
        ec = nw_eigenvector_centrality(NwGraph(net.n_agents, net.adj))
        sorted = sortperm(ec; rev=true)
        for k in 1:n_to_infect
            i = sorted[k]
            net.infected[i] = true
            net.agent_size[i] = 2.0
        end
    elseif params.reinfect_type == "PageRank-Centrality"
        pr = nw_page_rank(NwGraph(net.n_agents, net.adj))
        sorted = sortperm(pr; rev=true)
        for k in 1:n_to_infect
            i = sorted[k]
            net.infected[i] = true
            net.agent_size[i] = 2.0
        end
    end
end

struct SBotGoSystem <: System end

function update!(::SBotGoSystem, world::World)
    params = get_resource(world, SBotParams)
    rng    = get_resource(world, RNGResource).rng
    net    = get_resource(world, SBotNetwork)
    stats  = get_resource(world, SBotStats)

    # Check if all infected
    if all(net.infected)
        get_resource(world, Terminate).stop = true
        return nothing
    end

    # ask turtles with [infected? = true] — shuffle infected
    infected_ids = findall(net.infected)
    shuffle!(rng, infected_ids)

    for i in infected_ids
        mysize = net.agent_size[i]
        # ask link-neighbors with [infected? = false] — shuffle
        susceptible_nbrs = [j for j in net.adj[i] if !net.infected[j]]
        shuffle!(rng, susceptible_nbrs)
        for j in susceptible_nbrs
            prob = params.retention_loss ? params.p * mysize : params.p
            if rand(rng) <= prob
                net.infected[j] = true
                stats.num_infected += 1
            end
        end
    end

    # Check stagnation
    current_infected = count(net.infected)
    if current_infected == stats.previous_num_infected
        get_resource(world, Terminate).stop = true
        return nothing
    end
    stats.previous_num_infected = current_infected

    # Size reduction for all agents
    for i in 1:net.n_agents
        net.agent_size[i] /= params.size_reduction
        if net.agent_size[i] < 0.1
            net.infected[i] = false
        end
    end

    stats.num_infected = count(net.infected)
    return nothing
end

struct SBotTerminationSystem <: System end

function update!(::SBotTerminationSystem, world::World)
    params = get_resource(world, SBotParams)
    tick   = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
