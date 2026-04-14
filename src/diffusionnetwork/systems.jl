# Diffusion in Social Network and Utility Function
# Directed BA network; agents adopt beliefs based on weighted incoming influence

struct InitDiffusionNetworkSystem <: System end

function _dn_build_directed_ba!(net::DNNetwork, rng, n::Int, m::Int)
    # Build directed BA: nw:generate-preferential-attachment group influences members 1
    net.n = n
    resize!(net.in_links, n)
    resize!(net.p, n)
    resize!(net.oldsum, n)
    resize!(net.utility, n)
    for i in 1:n
        net.in_links[i] = Int[]
        net.p[i] = 0
        net.oldsum[i] = 0.0
        net.utility[i] = 0.0
    end

    # Start with m+1 fully connected nodes (directed: both directions)
    init = min(m + 1, n)
    for i in 1:init, j in 1:init
        i == j && continue
        push!(net.in_links[j], i)
        net.weights[(i, j)] = round(rand(rng) * 1000) / 1000
    end

    # Add remaining nodes with preferential attachment
    degree = zeros(Int, n)
    for j in 1:init
        degree[j] = length(net.in_links[j])
    end
    for i in (init+1):n
        total_degree = sum(degree[1:i-1])
        total_degree == 0 && continue
        targets = Set{Int}()
        attempts = 0
        while length(targets) < min(m, i-1) && attempts < 10000
            attempts += 1
            r = rand(rng) * total_degree
            cumulative = 0.0
            for j in 1:(i-1)
                cumulative += degree[j]
                if cumulative >= r
                    push!(targets, j)
                    break
                end
            end
        end
        for t in targets
            # Directed: t influences i
            push!(net.in_links[i], t)
            net.weights[(t, i)] = round(rand(rng) * 1000) / 1000
            degree[t] += 1
            degree[i] += 1
        end
    end
end

function initialize!(::InitDiffusionNetworkSystem, world::World)
    params = get_resource(world, DiffusionNetworkParams)
    rng = get_resource(world, RNGResource).rng
    net = get_resource(world, DNNetwork)
    stats = get_resource(world, DNStats)

    _dn_build_directed_ba!(net, rng, params.members, 1)

    # Assign initial beliefs: random 2 → 0 or 1
    for i in 1:net.n
        if rand(rng, 0:1) == 1
            net.p[i] = 1   # red
        else
            net.p[i] = -1  # grey
        end
    end

    stats.num_red = count(==(1), net.p)
    stats.num_grey = count(==(-1), net.p)
    return nothing
end

struct DNGoSystem <: System
    changing::Base.RefValue{Bool}
end
DNGoSystem() = DNGoSystem(Ref(true))

function update!(sys::DNGoSystem, world::World)
    params = get_resource(world, DiffusionNetworkParams)
    rng = get_resource(world, RNGResource).rng
    net = get_resource(world, DNNetwork)
    stats = get_resource(world, DNStats)

    if !sys.changing[]
        get_resource(world, Terminate).stop = true
        return nothing
    end

    sys.changing[] = false

    # Compute weighted sum of incoming influences for each agent
    for i in 1:net.n
        summer = 0.0
        for j in net.in_links[i]
            w = get(net.weights, (j, i), 0.0)
            summer += w * net.p[j]
        end
        old = round(net.oldsum[i]; digits=3)
        summer = round(summer; digits=3)
        if old != summer
            sys.changing[] = true
        end
        net.oldsum[i] = summer

        # Update belief based on threshold
        if summer > params.threshold
            net.p[i] = 1
        elseif summer < -params.threshold
            net.p[i] = -1
        end
    end

    # Compute utility
    for i in 1:net.n
        if isempty(net.in_links[i])
            net.utility[i] = Float64(net.p[i])
        else
            max_alt = -Inf
            for j in net.in_links[i]
                w = get(net.weights, (j, i), 0.0)
                alt = w * net.p[j]
                if alt > max_alt
                    max_alt = alt
                end
            end
            net.utility[i] = max_alt
        end
    end

    stats.num_red = count(==(1), net.p)
    stats.num_grey = count(==(-1), net.p)
    return nothing
end

struct DNTerminationSystem <: System end

function update!(::DNTerminationSystem, world::World)
    params = get_resource(world, DiffusionNetworkParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
