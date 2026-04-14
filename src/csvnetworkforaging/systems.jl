struct InitCNFSystem <: System end

function initialize!(::InitCNFSystem, world::World)
    params = get_resource(world, CNFParams)
    rng = get_resource(world, RNGResource).rng
    net = get_resource(world, CNFNetwork)
    stats = get_resource(world, CNFStats)

    # Create nodes from embedded data
    for nd in CNF_NODES
        push!(net.nodes, CNFNode(nd.id, nd.x, nd.y, nd.capacity, Float64(nd.capacity), nd.regrow_rate, Int[]))
    end

    # Build adjacency from edge list (undirected)
    for (a, b) in CNF_EDGES
        push!(net.nodes[a].neighbors, b)
        push!(net.nodes[b].neighbors, a)
    end

    # Create consumers at random nodes
    for _ in 1:params.num_consumers
        node_idx = rand(rng, 1:length(net.nodes))
        cr = 2 + rand(rng, 0:2)
        push!(net.consumers, CNFConsumer(30.0, cr, node_idx, true))
    end

    stats.total_consumed = 0.0
    _cnf_update_stats!(net, stats)
    return nothing
end

function _cnf_update_stats!(net::CNFNetwork, stats::CNFStats)
    s = 0.0
    for node in net.nodes
        s += node.supply
    end
    stats.total_supply = round(s; digits=4)
    stats.num_consumers = count(c -> c.alive, net.consumers)
    return nothing
end

struct CNFGoSystem <: System end

function update!(::CNFGoSystem, world::World)
    rng = get_resource(world, RNGResource).rng
    net = get_resource(world, CNFNetwork)
    stats = get_resource(world, CNFStats)

    # Regrow resources at each node
    for node in net.nodes
        node.supply = min(Float64(node.capacity), node.supply + node.regrow_rate)
    end

    # Shuffle alive consumer indices for NetLogo ask semantics
    alive_idxs = [i for i in eachindex(net.consumers) if net.consumers[i].alive]
    Random.shuffle!(rng, alive_idxs)

    for ci in alive_idxs
        c = net.consumers[ci]
        !c.alive && continue

        # Consume from current node
        node = net.nodes[c.node_idx]
        take = min(Float64(c.consumption_rate), node.supply)
        node.supply -= take
        c.energy += take
        stats.total_consumed += take

        # Metabolism
        c.energy -= 1.0

        # Move to best-supplied neighbor
        neighbors = node.neighbors
        if !isempty(neighbors)
            best_idx = neighbors[1]
            best_supply = net.nodes[best_idx].supply
            for ni in 2:length(neighbors)
                ns = net.nodes[neighbors[ni]].supply
                if ns > best_supply
                    best_supply = ns
                    best_idx = neighbors[ni]
                end
            end
            if best_supply > 0.0
                c.node_idx = best_idx
            end
        end

        # Die if energy depleted
        if c.energy <= 0.0
            c.alive = false
        end
    end

    # Reproduction (shuffled)
    alive_idxs2 = [i for i in eachindex(net.consumers) if net.consumers[i].alive]
    Random.shuffle!(rng, alive_idxs2)
    for ci in alive_idxs2
        c = net.consumers[ci]
        if c.alive && c.energy > 40.0
            child_energy = c.energy / 2.0
            c.energy = child_energy
            child_node = rand(rng, 1:length(net.nodes))
            push!(net.consumers, CNFConsumer(child_energy, c.consumption_rate, child_node, true))
        end
    end

    _cnf_update_stats!(net, stats)
    return nothing
end

struct CNFTerminationSystem <: System end

function update!(::CNFTerminationSystem, world::World)
    params = get_resource(world, CNFParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
