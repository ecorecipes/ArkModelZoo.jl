# Social Network Diffusion
# Directed BA network; belief diffusion with utility tracking

struct InitSNDSystem <: System end

function _snd_build_directed_ba!(net::SNDNetwork, rng, n::Int, m::Int)
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

    init = min(m + 1, n)
    for i in 1:init, j in 1:init
        i == j && continue
        push!(net.in_links[j], i)
        net.weights[(i, j)] = round(rand(rng) * 1000) / 1000
    end

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
            push!(net.in_links[i], t)
            net.weights[(t, i)] = round(rand(rng) * 1000) / 1000
            degree[t] += 1
            degree[i] += 1
        end
    end
end

function _snd_update_stats!(net::SNDNetwork, stats::SNDStats)
    stats.num_red = count(==(1), net.p)
    stats.num_grey = count(==(-1), net.p)
    if net.n > 0
        stats.avg_utility = sum(net.utility) / net.n
    else
        stats.avg_utility = 0.0
    end
end

function initialize!(::InitSNDSystem, world::World)
    params = get_resource(world, SocialNetDiffParams)
    rng = get_resource(world, RNGResource).rng
    net = get_resource(world, SNDNetwork)
    stats = get_resource(world, SNDStats)

    _snd_build_directed_ba!(net, rng, params.members, 1)

    for i in 1:net.n
        if rand(rng, 0:1) == 1
            net.p[i] = 1
        else
            net.p[i] = -1
        end
    end

    _snd_update_stats!(net, stats)
    return nothing
end

struct SNDGoSystem <: System
    changing::Base.RefValue{Bool}
end
SNDGoSystem() = SNDGoSystem(Ref(true))

function update!(sys::SNDGoSystem, world::World)
    params = get_resource(world, SocialNetDiffParams)
    rng = get_resource(world, RNGResource).rng
    net = get_resource(world, SNDNetwork)
    stats = get_resource(world, SNDStats)
    tick = get_resource(world, Tick)

    if !sys.changing[]
        get_resource(world, Terminate).stop = true
        return nothing
    end

    # NetLogo: if ticks > 20 [stop]
    if tick.tick > params.max_ticks
        get_resource(world, Terminate).stop = true
        return nothing
    end

    sys.changing[] = false

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

    _snd_update_stats!(net, stats)
    return nothing
end

struct SNDTerminationSystem <: System end

function update!(::SNDTerminationSystem, world::World)
    params = get_resource(world, SocialNetDiffParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
