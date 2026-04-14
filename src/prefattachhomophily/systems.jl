# Preferential Attachment with Homophily Networks
# Agents link to similar-wealth (homophily) or wealthier (resource dependence) nodes

struct InitPAHSystem <: System end

function initialize!(::InitPAHSystem, world::World)
    params = get_resource(world, PrefAttachHomophilyParams)
    rng = get_resource(world, RNGResource).rng
    net = get_resource(world, PAHNetwork)
    stats = get_resource(world, PAHStats)

    for _ in 1:params.number_of_nodes
        w = rand(rng, 0:19)
        ph = rand(rng, 0:max(params.probability_of_homophily - 1, 0))
        _pah_add_node!(net, w, ph)
    end

    stats.number_homophily = 0
    stats.num_links = 0
    return nothing
end

struct PAHGoSystem <: System end

function update!(::PAHGoSystem, world::World)
    params = get_resource(world, PrefAttachHomophilyParams)
    rng = get_resource(world, RNGResource).rng
    net = get_resource(world, PAHNetwork)
    stats = get_resource(world, PAHStats)

    net.n == 0 && return nothing

    # NetLogo: ask one-of turtles [find-partner, make-node-homophily]
    focal = rand(rng, 1:net.n)
    w = net.wealth[focal]
    prob_h = net.my_prob_homophily[focal]

    partner = 0
    if rand(rng, 0:99) < prob_h
        # Homophily: pick one-of other turtles with similar wealth (w-1, w, w+1)
        candidates = Int[]
        for j in 1:net.n
            j == focal && continue
            wj = net.wealth[j]
            if wj == w || wj == w - 1 || wj == w + 1
                push!(candidates, j)
            end
        end
        if !isempty(candidates)
            partner = candidates[rand(rng, 1:length(candidates))]
        end
    else
        # Resource dependence: pick one-of other turtles with wealth > w
        candidates = Int[]
        for j in 1:net.n
            j == focal && continue
            if net.wealth[j] > w
                push!(candidates, j)
            end
        end
        if !isempty(candidates)
            partner = candidates[rand(rng, 1:length(candidates))]
        end
    end

    if partner != 0
        _pah_add_edge!(net, focal, partner)
    end

    # Check stop: number-homophily >= number-of-links
    stats.number_homophily += 1
    stats.num_links = _pah_num_links(net)

    if stats.number_homophily >= params.number_of_links
        get_resource(world, Terminate).stop = true
    end
    return nothing
end

struct PAHTerminationSystem <: System end

function update!(::PAHTerminationSystem, world::World)
    params = get_resource(world, PrefAttachHomophilyParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
