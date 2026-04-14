# --- Initialization ---

struct InitLCSystem <: System end

function initialize!(::InitLCSystem, world::World)
    params = get_resource(world, LCParams)
    rng = get_resource(world, RNGResource).rng
    network = get_resource(world, LCNetwork)

    n = params.num_nodes
    network.neighbors = [Int[] for _ in 1:n]
    network.node_entities = Vector{Entity}(undef, n)

    # Create nodes
    for i in 1:n
        eid = new_entity!(world, (LCNode(0.0, 0.0, i),))
        network.node_entities[i] = eid
    end

    # Distribute grammars: percent_grammar_1% start with state=1.0
    num_g1 = round(Int, params.percent_grammar_1 / 100.0 * n)
    indices = collect(1:n)
    Random.shuffle!(rng, indices)
    for i in 1:num_g1
        node = get_components(world, network.node_entities[indices[i]], (LCNode,))[1]
        node.state = 1.0
        node.spoken_state = 1.0
    end

    # Create preferential attachment network
    # Start with edge between node 1 and 2
    if n >= 2
        _lc_add_edge!(network, 1, 2)
    end
    connected = Set{Int}([1, 2])
    unconnected = collect(3:n)
    Random.shuffle!(rng, unconnected)

    for new_node in unconnected
        # Find partner via preferential attachment
        partner = _lc_find_partner(rng, network, connected)
        _lc_add_edge!(network, new_node, partner)
        push!(connected, new_node)
    end

    _lc_update_stats!(world)
    return nothing
end

function _lc_add_edge!(network::LCNetwork, i::Int, j::Int)
    push!(network.neighbors[i], j)
    push!(network.neighbors[j], i)
end

function _lc_find_partner(rng, network::LCNetwork, connected::Set{Int})
    # Preferential attachment: probability proportional to degree
    nodes = collect(connected)
    degrees = [length(network.neighbors[n]) for n in nodes]
    total = sum(degrees)
    if total == 0
        return nodes[rand(rng, 1:length(nodes))]
    end
    pick = rand(rng) * total
    cumsum = 0.0
    for (idx, n) in enumerate(nodes)
        cumsum += degrees[idx]
        if cumsum >= pick
            return n
        end
    end
    return nodes[end]
end

function _lc_update_stats!(world::World)
    stats = get_resource(world, LCStats)
    total = 0.0
    n = 0
    ng0 = 0
    ng1 = 0
    for (_, nodes) in Query(world, (LCNode,))
        @inbounds for i in eachindex(nodes)
            total += nodes[i].state
            n += 1
            if nodes[i].state >= 0.5
                ng1 += 1
            else
                ng0 += 1
            end
        end
    end
    stats.mean_state = n > 0 ? total / n : 0.0
    stats.num_grammar_0 = ng0
    stats.num_grammar_1 = ng1
end

# --- Go ---

struct LCGoSystem <: System end

function update!(::LCGoSystem, world::World)
    params = get_resource(world, LCParams)
    rng = get_resource(world, RNGResource).rng
    network = get_resource(world, LCNetwork)

    # Collect nodes for shuffled ask
    node_indices = collect(1:length(network.node_entities))
    Random.shuffle!(rng, node_indices)

    if params.update_algorithm == :threshold
        for idx in node_indices
            node = get_components(world, network.node_entities[idx], (LCNode,))[1]
            nbrs = network.neighbors[idx]
            if isempty(nbrs)
                continue
            end
            grammar_one_sum = 0.0
            for nb in nbrs
                nb_node = get_components(world, network.node_entities[nb], (LCNode,))[1]
                grammar_one_sum += nb_node.state
            end
            if grammar_one_sum >= length(nbrs) * params.threshold_val
                node.state = 1.0
            else
                if !params.sink_state_1
                    node.state = 0.0
                end
            end
        end
    elseif params.update_algorithm == :individual
        for idx in node_indices
            node = get_components(world, network.node_entities[idx], (LCNode,))[1]
            nbrs = network.neighbors[idx]
            isempty(nbrs) && continue
            nb = nbrs[rand(rng, 1:length(nbrs))]
            nb_node = get_components(world, network.node_entities[nb], (LCNode,))[1]
            node.state = nb_node.state
        end
    elseif params.update_algorithm == :reward
        # Speak phase
        for idx in node_indices
            node = get_components(world, network.node_entities[idx], (LCNode,))[1]
            if params.logistic
                gain = (params.alpha + 0.1) * 20.0
                filter_val = 1.0 / (1.0 + exp(-(gain * node.state - 1.0) * 5.0))
                node.spoken_state = rand(rng) <= filter_val ? 1.0 : 0.0
            else
                biased_val = min(1.5 * node.state, 1.0)
                node.spoken_state = rand(rng) <= biased_val ? 1.0 : 0.0
            end
        end
        # Listen phase
        for idx in node_indices
            node = get_components(world, network.node_entities[idx], (LCNode,))[1]
            nbrs = network.neighbors[idx]
            for nb in nbrs
                nb_node = get_components(world, network.node_entities[nb], (LCNode,))[1]
                heard = nb_node.spoken_state
                gamma = 0.01
                if rand(rng) <= node.state
                    if heard == 1.0
                        node.state += gamma * (1.0 - node.state)
                    else
                        node.state = (1.0 - gamma) * node.state
                    end
                else
                    if heard == 0.0
                        node.state = node.state * (1.0 - gamma)
                    else
                        node.state = gamma + node.state * (1.0 - gamma)
                    end
                end
            end
        end
    end

    _lc_update_stats!(world)
    return nothing
end

# --- Termination ---

struct LCTerminationSystem <: System end

function update!(::LCTerminationSystem, world::World)
    params = get_resource(world, LCParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
