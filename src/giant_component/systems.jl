# --- Initialization ---

struct InitGCSystem <: System end

function initialize!(::InitGCSystem, world::World)
    params = get_resource(world, GCParams)
    net = get_resource(world, GCNetwork)
    stats = get_resource(world, GCStats)

    # Create a single dummy entity (network is tracked in resources)
    new_entity!(world, (GCDummy(),))

    # Initial state: no edges, each node is its own component
    _gc_find_components!(net, stats)
    return nothing
end

# --- Main Go System ---

struct GCGoSystem <: System end

function update!(::GCGoSystem, world::World)
    net = get_resource(world, GCNetwork)
    stats = get_resource(world, GCStats)
    rng = get_resource(world, RNGResource).rng

    n = net.num_nodes
    max_edges = n * (n - 1) ÷ 2

    # Fully connected check
    net.num_edges >= max_edges && return nothing

    # Add one random edge between two unconnected nodes
    _gc_add_edge!(net, rng)

    # Recompute components
    _gc_find_components!(net, stats)
    return nothing
end

function _gc_add_edge!(net::GCNetwork, rng)
    n = net.num_nodes
    for _ in 1:10_000
        a = rand(rng, 1:n)
        b = rand(rng, 1:n)
        a == b && continue
        b ∈ net.adj[a] && continue
        push!(net.adj[a], b)
        push!(net.adj[b], a)
        net.num_edges += 1
        return nothing
    end
    return nothing
end

function _gc_find_components!(net::GCNetwork, stats::GCStats)
    n = net.num_nodes
    visited = falses(n)
    giant = 0
    num_components = 0

    # BFS for each unvisited node
    queue = Int[]
    for start in 1:n
        visited[start] && continue
        num_components += 1
        comp_size = 0

        # BFS from start
        empty!(queue)
        push!(queue, start)
        visited[start] = true
        while !isempty(queue)
            node = popfirst!(queue)
            comp_size += 1
            for neighbor in net.adj[node]
                if !visited[neighbor]
                    visited[neighbor] = true
                    push!(queue, neighbor)
                end
            end
        end

        if comp_size > giant
            giant = comp_size
        end
    end

    stats.giant_component_size = giant
    stats.num_edges = net.num_edges
    stats.num_components = num_components
    stats.fraction_in_giant = n > 0 ? giant / n : 0.0
    return nothing
end

# --- Termination ---

struct GCTerminationSystem <: System end

function update!(::GCTerminationSystem, world::World)
    net = get_resource(world, GCNetwork)
    params = get_resource(world, GCParams)
    tick = get_resource(world, Tick)

    n = net.num_nodes
    max_edges = n * (n - 1) ÷ 2

    if net.num_edges >= max_edges || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
