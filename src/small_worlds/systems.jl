struct InitSWSystem <: System end

function _sw_is_connected(g::NwGraph)
    g.n <= 1 && return true
    comps = nw_connected_components(g)
    return length(comps) == 1
end

function initialize!(::InitSWSystem, world::World)
    params = get_resource(world, SWParams)
    rng = get_resource(world, RNGResource).rng
    net = get_resource(world, SWNetwork)
    stats = get_resource(world, SWStats)
    n = params.num_nodes

    # Create entities
    net.node_to_entity = Vector{Entity}(undef, n)
    for i in 1:n
        eid = new_entity!(world, (SWNode(i),))
        net.node_to_entity[i] = eid
    end

    # Build ring lattice with k=4 (each node connected to next 2 neighbors)
    g = NwGraph(n)
    for i in 1:n
        for d in 1:2
            j = mod1(i + d, n)
            nw_add_edge!(g, i, j)
        end
    end
    net.graph = g

    # Calculate lattice properties
    stats.clustering_coefficient_of_lattice = nw_mean_clustering_coefficient(g)
    stats.average_path_length_of_lattice = nw_mean_path_length(g)
    stats.clustering_coefficient = stats.clustering_coefficient_of_lattice
    stats.average_path_length = stats.average_path_length_of_lattice
    stats.number_rewired = 0

    return nothing
end

struct SWRewireSystem <: System end

function update!(::SWRewireSystem, world::World)
    params = get_resource(world, SWParams)
    rng = get_resource(world, RNGResource).rng
    net = get_resource(world, SWNetwork)
    stats = get_resource(world, SWStats)
    n = params.num_nodes

    # Rewire-all: try until we get a connected network
    for _attempt in 1:100
        # Start from fresh ring lattice
        g = NwGraph(n)
        for i in 1:n
            for d in 1:2
                j = mod1(i + d, n)
                nw_add_edge!(g, i, j)
            end
        end

        num_rewired = 0
        # Collect all original edges
        edges = Tuple{Int,Int}[]
        for i in 1:n
            for d in 1:2
                j = mod1(i + d, n)
                push!(edges, (i, j))
            end
        end

        for (node1, old_j) in edges
            rand(rng) >= params.rewiring_probability && continue
            nw_degree(g, node1) >= n - 1 && continue
            # Find a new target
            node2 = rand(rng, 1:n)
            attempts = 0
            while (node2 == node1 || nw_has_edge(g, node1, node2)) && attempts < 100
                node2 = rand(rng, 1:n)
                attempts += 1
            end
            attempts >= 100 && continue
            # Rewire
            if nw_has_edge(g, node1, old_j)
                nw_remove_edge!(g, node1, old_j)
                nw_add_edge!(g, node1, node2)
                num_rewired += 1
            end
        end

        if _sw_is_connected(g)
            net.graph = g
            stats.number_rewired = num_rewired
            stats.clustering_coefficient = nw_mean_clustering_coefficient(g)
            stats.average_path_length = nw_mean_path_length(g)
            return nothing
        end
    end
    # Fallback: keep original lattice
    return nothing
end

struct SWTerminationSystem <: System end

function update!(::SWTerminationSystem, world::World)
    params = get_resource(world, SWParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
