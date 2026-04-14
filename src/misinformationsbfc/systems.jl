# Misinformation SBFC — Susceptible-Believer-FactChecker dynamics on BA network

struct InitMisSBFCSystem <: System end

function initialize!(::InitMisSBFCSystem, world::World)
    params = get_resource(world, MisSBFCParams)
    rng    = get_resource(world, RNGResource).rng
    net    = get_resource(world, MisSBFCNetwork)
    stats  = get_resource(world, MisSBFCStats)

    # Build BA network using nw extension
    g = nw_generate_preferential_attachment(rng, params.number_of_agents, 3)
    for i in 1:g.n
        _msb_add_agent!(net)
    end
    net.adj = g.adj

    # Initialize states: 90% S, 10% B
    order = shuffle!(rng, collect(1:net.n_agents))
    for i in order
        if rand(rng, 0:99) <= 90
            net.state[i] = 'S'
        else
            net.state[i] = 'B'
        end
    end

    _msb_update_stats!(net, stats)
    return nothing
end

function _msb_update_stats!(net::MisSBFCNetwork, stats::MisSBFCStats)
    stats.num_believers = count(==('B'), net.state)
    stats.num_factcheckers = count(==('F'), net.state)
    stats.num_susceptibles = count(==('S'), net.state)
end

struct MisSBFCGoSystem <: System end

function update!(::MisSBFCGoSystem, world::World)
    params = get_resource(world, MisSBFCParams)
    rng    = get_resource(world, RNGResource).rng
    net    = get_resource(world, MisSBFCNetwork)
    stats  = get_resource(world, MisSBFCStats)

    # Spreading: ask turtles with [state = "S"]
    susceptibles = findall(==('S'), net.state)
    shuffle!(rng, susceptibles)
    for i in susceptibles
        nB = count(j -> net.state[j] == 'B', net.adj[i])
        nF = count(j -> net.state[j] == 'F', net.adj[i])
        a1 = 1.0 + params.alpha_hoax_credibility
        a0 = 1.0 - params.alpha_hoax_credibility
        den = nB * a1 + nF * a0
        f = 0.0
        g = 0.0
        if den != 0.0
            f = params.beta_spreading_rate * (nB * a1 / den)
            g = params.beta_fc_spread * (nF * a0 / den)
        end
        r = rand(rng)
        if r < f
            net.state[i] = 'B'
        elseif r < f + g
            net.state[i] = 'F'
        end
    end

    # Forgetting: believers forget
    believers = findall(==('B'), net.state)
    shuffle!(rng, believers)
    for i in believers
        if rand(rng) < params.pForget
            net.state[i] = 'S'
        end
    end

    # Forgetting: factcheckers forget
    factcheckers = findall(==('F'), net.state)
    shuffle!(rng, factcheckers)
    for i in factcheckers
        if rand(rng) < params.pForget_FC
            net.state[i] = 'S'
        end
    end

    # Verifying: believers become factcheckers
    believers2 = findall(==('B'), net.state)
    shuffle!(rng, believers2)
    for i in believers2
        if rand(rng) < params.pVerify
            net.state[i] = 'F'
        end
    end

    _msb_update_stats!(net, stats)
    return nothing
end

struct MisSBFCTerminationSystem <: System end

function update!(::MisSBFCTerminationSystem, world::World)
    params = get_resource(world, MisSBFCParams)
    tick   = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
