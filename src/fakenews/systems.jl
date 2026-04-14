# Fake News — cascade/Bass info diffusion on Erdős-Rényi network

struct InitFNewsSystem <: System end

function _fnews_build_er!(net::FNewsNetwork, rng, n::Int, p::Float64)
    for _ in 1:n
        _fnews_add_agent!(net)
    end
    for i in 1:n, j in (i+1):n
        if rand(rng) < p
            _fnews_add_edge!(net, i, j)
        end
    end
end

function initialize!(::InitFNewsSystem, world::World)
    params = get_resource(world, FNewsParams)
    rng    = get_resource(world, RNGResource).rng
    net    = get_resource(world, FNewsNetwork)
    stats  = get_resource(world, FNewsStats)

    # Erdős-Rényi graph
    edge_prob = (2.0 * params.mean_degree) / (params.num_agents - 1)
    _fnews_build_er!(net, rng, params.num_agents, edge_prob)

    # Select seed informers
    indices = shuffle!(rng, collect(1:net.n_agents))
    for k in 1:min(params.num_seed_informers, net.n_agents)
        i = indices[k]
        net.aware[i] = true
        net.seed_agent[i] = true
        net.tick_become_aware[i] = -1
    end

    _fnews_update_stats!(net, stats)
    return nothing
end

function _fnews_update_stats!(net::FNewsNetwork, stats::FNewsStats)
    n_aware = count(net.aware)
    n = net.n_agents
    stats.pct_aware   = n > 0 ? n_aware / n * 100.0 : 0.0
    stats.pct_unaware = n > 0 ? (n - n_aware) / n * 100.0 : 0.0
end

# --- Cascade spread + broadcast ---
struct FNewsGoSystem <: System end

function update!(::FNewsGoSystem, world::World)
    params = get_resource(world, FNewsParams)
    rng    = get_resource(world, RNGResource).rng
    net    = get_resource(world, FNewsNetwork)
    stats  = get_resource(world, FNewsStats)
    tick   = get_resource(world, Tick)

    # Cascade: ask turtles with [tick-become-aware = (ticks - 1)] [pass-adopt]
    # NetLogo: build filtered agentset FIRST, then shuffle ONLY matching agents
    cascade_agents = [i for i in 1:net.n_agents if net.tick_become_aware[i] == tick.tick - 1]
    shuffle!(rng, cascade_agents)
    for i in cascade_agents
        # pass-adopt: ask link-neighbors with [not aware?] — shuffled
        unadopted = Int[]
        for j in net.adj[i]
            !net.aware[j] && push!(unadopted, j)
        end
        shuffle!(rng, unadopted)
        for j in unadopted
            if rand(rng) < params.influence_rate
                net.aware[j] = true
                net.tick_become_aware[j] = tick.tick
            end
        end
    end

    # Broadcast: ask turtles with [not aware?] [adopt] — shuffled
    unaware_agents = [i for i in 1:net.n_agents if !net.aware[i]]
    shuffle!(rng, unaware_agents)
    for i in unaware_agents
        if rand(rng) < params.broadcast_influence
            net.aware[i] = true
            net.tick_become_aware[i] = tick.tick
        end
    end

    _fnews_update_stats!(net, stats)
    return nothing
end

# --- Termination ---
struct FNewsTerminationSystem <: System end

function update!(::FNewsTerminationSystem, world::World)
    params = get_resource(world, FNewsParams)
    tick   = get_resource(world, Tick)
    net    = get_resource(world, FNewsNetwork)

    all_aware = all(net.aware)
    if all_aware || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
