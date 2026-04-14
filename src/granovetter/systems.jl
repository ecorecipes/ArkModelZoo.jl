# --- Initialization ---

struct InitGRANSystem <: System end

function initialize!(::InitGRANSystem, world::World)
    params = get_resource(world, GRANParams)
    rng = get_resource(world, RNGResource).rng
    n = params.number_of_agents
    network = get_resource(world, GRANNetwork)

    # Create agents
    agent_eids = Entity[]
    agents = GRANAgent[]
    for i in 1:n
        ag = GRANAgent()
        ag.id = i
        ag.riot = false

        if params.threshold_distribution == "uniform"
            lo = params.min_threshold
            hi = params.max_threshold
            ag.threshold = lo + rand(rng) * (hi - lo)
        else
            ag.threshold = round(params.mean_threshold + params.sd_threshold * randn(rng))
        end
        ag.threshold = clamp(ag.threshold, 0.0, 100.0)

        eid = new_entity!(world, (ag,))
        push!(agent_eids, eid)
        push!(agents, ag)
    end

    # Build network
    if params.network == "fully connected"
        for i in 1:n, j in i+1:n
            _gran_add_edge!(network, i, j)
        end
    elseif params.network == "small-world"
        # Ring lattice
        for i in 1:n
            for k in 1:params.number_of_links
                j = mod1(i + k, n)
                if !(j in network.neighbors[i])
                    _gran_add_edge!(network, i, j)
                end
            end
        end
        # Rewire
        nrewire = round(Int, params.rewire_prop * n)
        for _ in 1:nrewire
            i = rand(rng, 1:n)
            if !isempty(network.neighbors[i])
                # Remove a random edge
                j_idx = rand(rng, 1:length(network.neighbors[i]))
                j = network.neighbors[i][j_idx]
                deleteat!(network.neighbors[i], j_idx)
                filter!(x -> x != i, network.neighbors[j])
                # Add random edge
                candidates = [k for k in 1:n if k != i && !(k in network.neighbors[i])]
                if !isempty(candidates)
                    new_j = candidates[rand(rng, 1:length(candidates))]
                    _gran_add_edge!(network, i, new_j)
                end
            end
        end
    else  # random
        for i in 1:n
            candidates = [k for k in 1:n if k != i && !(k in network.neighbors[i])]
            nlinks = min(params.number_of_links, length(candidates))
            if nlinks > 0
                Random.shuffle!(rng, candidates)
                for j in candidates[1:nlinks]
                    if !(j in network.neighbors[i])
                        _gran_add_edge!(network, i, j)
                    end
                end
            end
        end
    end

    _gran_update_stats!(world)
    return nothing
end

function _gran_add_edge!(nw::GRANNetwork, i::Int, j::Int)
    if !(j in nw.neighbors[i])
        push!(nw.neighbors[i], j)
    end
    if !(i in nw.neighbors[j])
        push!(nw.neighbors[j], i)
    end
end

# --- Go ---

struct GRANGoSystem <: System end

function update!(::GRANGoSystem, world::World)
    network = get_resource(world, GRANNetwork)

    # Collect all agents keyed by id
    agent_map = Dict{Int, GRANAgent}()
    for (_, agents) in Query(world, (GRANAgent,))
        for ag in agents
            agent_map[ag.id] = ag
        end
    end

    # Each agent checks proportion of rioting neighbors
    for (_, agents) in Query(world, (GRANAgent,))
        for ag in agents
            nbrs = network.neighbors[ag.id]
            isempty(nbrs) && continue
            rioting_nbrs = count(j -> agent_map[j].riot, nbrs)
            prop_rioting = 100.0 * rioting_nbrs / length(nbrs)
            if prop_rioting >= ag.threshold
                ag.riot = true
            end
        end
    end

    _gran_update_stats!(world)
    return nothing
end

function _gran_update_stats!(world::World)
    stats = get_resource(world, GRANStats)
    total = 0
    rioting = 0
    for (_, agents) in Query(world, (GRANAgent,))
        for ag in agents
            total += 1
            if ag.riot
                rioting += 1
            end
        end
    end
    stats.num_rioting = rioting
    stats.percent_rioting = total > 0 ? 100.0 * rioting / total : 0.0
end

# --- Termination ---

struct GRANTerminationSystem <: System end

function update!(::GRANTerminationSystem, world::World)
    params = get_resource(world, GRANParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
