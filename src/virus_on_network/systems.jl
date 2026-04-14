struct InitVONSystem <: System end

function initialize!(::InitVONSystem, world::World)
    params = get_resource(world, VONParams)
    rng = get_resource(world, RNGResource).rng
    net = get_resource(world, VONNetwork)
    n = params.number_of_nodes

    # Build spatially-clustered network: connect nearest non-neighbors
    num_links = div(params.average_node_degree * n, 2)
    g = NwGraph(n)
    # Assign random positions for spatial clustering
    pos_x = [rand(rng) for _ in 1:n]
    pos_y = [rand(rng) for _ in 1:n]
    for _ in 1:num_links
        # Pick random node, connect to nearest non-neighbor
        i = rand(rng, 1:n)
        best_j = 0
        best_dist = Inf
        for j in 1:n
            j == i && continue
            nw_has_edge(g, i, j) && continue
            d = (pos_x[i] - pos_x[j])^2 + (pos_y[i] - pos_y[j])^2
            if d < best_dist
                best_dist = d
                best_j = j
            end
        end
        if best_j > 0
            nw_add_edge!(g, i, best_j)
        end
    end
    net.graph = g

    # Create entities for each node
    net.node_to_entity = Vector{Entity}(undef, n)
    for i in 1:n
        timer = rand(rng, 0:max(params.virus_check_frequency - 1, 0))
        eid = new_entity!(world, (VONState(i, false, false, timer),))
        net.node_to_entity[i] = eid
    end

    # Infect initial outbreak
    outbreak_ids = Random.shuffle!(rng, collect(1:n))[1:min(params.initial_outbreak_size, n)]
    for i in outbreak_ids
        st = get_components(world, net.node_to_entity[i], (VONState,))[1]
        st.infected = true
    end

    _von_update_stats!(world)
    return nothing
end

struct VONGoSystem <: System end

function update!(::VONGoSystem, world::World)
    params = get_resource(world, VONParams)
    rng = get_resource(world, RNGResource).rng
    net = get_resource(world, VONNetwork)

    # Increment virus check timers (shuffled ask)
    all_nodes = collect(1:net.graph.n)
    Random.shuffle!(rng, all_nodes)
    for i in all_nodes
        st = get_components(world, net.node_to_entity[i], (VONState,))[1]
        st.virus_check_timer += 1
        if st.virus_check_timer >= params.virus_check_frequency
            st.virus_check_timer = 0
        end
    end

    # Spread virus
    Random.shuffle!(rng, all_nodes)
    for i in all_nodes
        st = get_components(world, net.node_to_entity[i], (VONState,))[1]
        !st.infected && continue
        neighbors = collect(nw_neighbors(net.graph, i))
        Random.shuffle!(rng, neighbors)
        for j in neighbors
            nst = get_components(world, net.node_to_entity[j], (VONState,))[1]
            nst.resistant && continue
            if rand(rng) * 100.0 < params.virus_spread_chance
                nst.infected = true
            end
        end
    end

    # Virus checks
    Random.shuffle!(rng, all_nodes)
    for i in all_nodes
        st = get_components(world, net.node_to_entity[i], (VONState,))[1]
        (!st.infected || st.virus_check_timer != 0) && continue
        if rand(rng, 0:99) < params.recovery_chance
            if rand(rng, 0:99) < params.gain_resistance_chance
                st.infected = false
                st.resistant = true
            else
                st.infected = false
            end
        end
    end

    _von_update_stats!(world)
    return nothing
end

function _von_update_stats!(world::World)
    stats = get_resource(world, VONStats)
    ns = 0; ni = 0; nr = 0
    for (_, states) in Query(world, (VONState,))
        @inbounds for k in eachindex(states)
            s = states[k]
            if s.resistant
                nr += 1
            elseif s.infected
                ni += 1
            else
                ns += 1
            end
        end
    end
    stats.num_susceptible = ns
    stats.num_infected = ni
    stats.num_resistant = nr
end

struct VONTerminationSystem <: System end

function update!(::VONTerminationSystem, world::World)
    params = get_resource(world, VONParams)
    stats = get_resource(world, VONStats)
    tick = get_resource(world, Tick)
    if stats.num_infected == 0 || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
