struct InitPASystem <: System end

function initialize!(::InitPASystem, world::World)
    net = get_resource(world, PANetwork)
    net.graph = NwGraph(2)
    nw_add_edge!(net.graph, 1, 2)
    net.node_to_entity = Vector{Entity}(undef, 2)
    for i in 1:2
        eid = new_entity!(world, (PANode(i, 1),))
        net.node_to_entity[i] = eid
    end
    _pa_update_stats!(world)
    return nothing
end

struct PAGoSystem <: System end

function update!(::PAGoSystem, world::World)
    params = get_resource(world, PAParams)
    rng = get_resource(world, RNGResource).rng
    net = get_resource(world, PANetwork)
    g = net.graph

    g.n >= params.max_nodes && return nothing

    # Find partner via preferential attachment (proportional to degree)
    total_degree = sum(nw_degree(g, k) for k in 1:g.n)
    r = rand(rng) * total_degree
    partner = g.n  # fallback
    cumul = 0.0
    for k in 1:g.n
        cumul += nw_degree(g, k)
        if cumul >= r
            partner = k
            break
        end
    end

    # Add new node
    new_id = nw_add_node!(g)
    nw_add_edge!(g, new_id, partner)
    eid = new_entity!(world, (PANode(new_id, 1),))
    push!(net.node_to_entity, eid)

    # Update partner degree component
    pst = get_components(world, net.node_to_entity[partner], (PANode,))[1]
    pst.degree = nw_degree(g, partner)

    _pa_update_stats!(world)
    return nothing
end

function _pa_update_stats!(world::World)
    net = get_resource(world, PANetwork)
    stats = get_resource(world, PAStats)
    g = net.graph
    stats.num_nodes = g.n
    stats.num_edges = sum(nw_degree(g, i) for i in 1:g.n; init=0) ÷ 2
    stats.max_degree = g.n > 0 ? maximum(nw_degree(g, i) for i in 1:g.n) : 0
end

struct PATerminationSystem <: System end

function update!(::PATerminationSystem, world::World)
    params = get_resource(world, PAParams)
    net = get_resource(world, PANetwork)
    tick = get_resource(world, Tick)
    if net.graph.n >= params.max_nodes || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
