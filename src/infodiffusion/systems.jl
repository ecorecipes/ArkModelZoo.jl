struct InitInfoDiffSystem <: System end

function _infodiff_build_ba!(net::InfoDiffNetwork, rng, n::Int, m::Int)
    # Start with m+1 fully connected nodes
    for i in 1:(m+1)
        _infodiff_add_agent!(net, 0)
    end
    for i in 1:(m+1), j in (i+1):(m+1)
        _infodiff_add_edge!(net, i, j)
    end
    # Add remaining nodes with preferential attachment
    for _ in (m+2):n
        new_id = _infodiff_add_agent!(net, 0)
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
            _infodiff_add_edge!(net, new_id, t)
        end
    end
end

function initialize!(::InitInfoDiffSystem, world::World)
    params = get_resource(world, InfoDiffParams)
    rng = get_resource(world, RNGResource).rng
    net = get_resource(world, InfoDiffNetwork)
    stats = get_resource(world, InfoDiffStats)

    _infodiff_build_ba!(net, rng, params.n_agents, params.ba_m)

    # Assign initial states: 90% S, 10% B
    for i in 1:net.n_agents
        if rand(rng, 0:99) <= 90
            net.states[i] = 0  # S
        else
            net.states[i] = 1  # B
        end
    end

    _infodiff_update_counts!(net, stats)
    return nothing
end

function _infodiff_update_counts!(net::InfoDiffNetwork, stats::InfoDiffStats)
    stats.num_believers = count(==(1), net.states)
    stats.num_factcheckers = count(==(2), net.states)
    stats.num_susceptibles = count(==(0), net.states)
end

struct InfoDiffGoSystem <: System end

function update!(::InfoDiffGoSystem, world::World)
    params = get_resource(world, InfoDiffParams)
    rng = get_resource(world, RNGResource).rng
    net = get_resource(world, InfoDiffNetwork)
    stats = get_resource(world, InfoDiffStats)

    # Spreading: S agents may become B or F based on neighbor states
    new_states = copy(net.states)
    for i in 1:net.n_agents
        net.states[i] == 0 || continue  # only S
        nB = 0
        nF = 0
        for j in net.adj[i]
            if net.states[j] == 1
                nB += 1
            elseif net.states[j] == 2
                nF += 1
            end
        end
        _1pa = 1.0 + params.alpha
        _1ma = 1.0 - params.alpha
        den = nB * _1pa + nF * _1ma
        f = 0.0
        g = 0.0
        if den != 0.0
            f = params.beta * (nB * _1pa / den)
            g = params.beta * (nF * _1ma / den)
        end
        r = rand(rng)
        if r < f
            new_states[i] = 1  # B
        elseif r < f + g
            new_states[i] = 2  # F
        end
    end
    copy!(net.states, new_states)

    # Forgetting: B/F → S
    for i in 1:net.n_agents
        if net.states[i] == 1 || net.states[i] == 2
            if rand(rng) < params.p_forget
                net.states[i] = 0
            end
        end
    end

    # Verifying: B → F
    for i in 1:net.n_agents
        if net.states[i] == 1
            if rand(rng) < params.p_verify
                net.states[i] = 2
            end
        end
    end

    _infodiff_update_counts!(net, stats)
    return nothing
end

struct InfoDiffTerminationSystem <: System end

function update!(::InfoDiffTerminationSystem, world::World)
    params = get_resource(world, InfoDiffParams)
    tick = get_resource(world, Tick)
    # NetLogo: tick at start of go, stop if ticks > 300
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
