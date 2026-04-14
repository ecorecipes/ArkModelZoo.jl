# Slow Spread of Environmental Action — opinion dynamics with community structure

struct InitSSpreadSystem <: System end

function _sspread_build_ba!(net::SSpreadNetwork, rng, start_id::Int, n::Int, m::Int, color::Int)
    ids = Int[]
    # Create m+1 initial fully connected nodes
    for _ in 1:(m+1)
        id = _sspread_add_agent!(net, color)
        push!(ids, id)
    end
    for i in 1:length(ids), j in (i+1):length(ids)
        _sspread_add_edge!(net, ids[i], ids[j])
    end
    # Preferential attachment for remaining
    for _ in (m+2):n
        new_id = _sspread_add_agent!(net, color)
        push!(ids, new_id)
        # Degree sum among existing nodes in this sub-network
        total_deg = 0
        for id in ids[1:end-1]
            total_deg += net.degree[id]
        end
        targets = Set{Int}()
        attempts = 0
        while length(targets) < m && attempts < 10000
            attempts += 1
            if total_deg == 0
                # Uniform random
                push!(targets, ids[rand(rng, 1:length(ids)-1)])
            else
                r = rand(rng) * total_deg
                cumulative = 0.0
                for id in ids[1:end-1]
                    cumulative += net.degree[id]
                    if cumulative >= r
                        push!(targets, id)
                        break
                    end
                end
            end
        end
        for t in targets
            _sspread_add_edge!(net, new_id, t)
        end
    end
    return ids
end

# Louvain community detection (matches NetLogo nw:louvain-communities)
function _sspread_louvain!(net::SSpreadNetwork, rng; max_passes::Int=100)
    n = net.n_agents
    n <= 1 && return

    total_edges = 0
    for i in 1:n
        total_edges += net.degree[i]
    end
    m = total_edges ÷ 2  # each edge counted twice in degree sum
    m == 0 && return
    mf = Float64(m)

    comm = collect(1:n)

    for _ in 1:max_passes
        moved = false
        order = shuffle!(rng, collect(1:n))
        for i in order
            ci = comm[i]
            ki = net.degree[i]
            isempty(net.adj[i]) && continue

            # Edges from i to each neighboring community
            ki_to = Dict{Int,Int}()
            for j in net.adj[i]
                cj = comm[j]
                ki_to[cj] = get(ki_to, cj, 0) + 1
            end

            # Total degree of each relevant community
            sigma_tot = Dict{Int,Int}()
            for j in 1:n
                cj = comm[j]
                if cj == ci || haskey(ki_to, cj)
                    sigma_tot[cj] = get(sigma_tot, cj, 0) + net.degree[j]
                end
            end

            ki_in_ci = get(ki_to, ci, 0)
            sigma_ci = get(sigma_tot, ci, 0)

            best_c = ci
            best_dq = 0.0
            for (c, ki_in_c) in ki_to
                c == ci && continue
                sigma_c = get(sigma_tot, c, 0)
                dq = (ki_in_c - ki_in_ci) / mf +
                     ki * ((sigma_ci - ki) - sigma_c) / (2.0 * mf * mf)
                if dq > best_dq
                    best_dq = dq
                    best_c = c
                end
            end

            if best_c != ci
                comm[i] = best_c
                moved = true
            end
        end
        !moved && break
    end

    for i in 1:n
        net.community[i] = comm[i]
    end
end

function initialize!(::InitSSpreadSystem, world::World)
    params = get_resource(world, SSpreadParams)
    rng    = get_resource(world, RNGResource).rng
    net    = get_resource(world, SSpreadNetwork)
    stats  = get_resource(world, SSpreadStats)

    # NetLogo passes k-degree directly as min-degree to nw:generate-preferential-attachment
    # (each new node creates k_degree links), NOT k_degree÷2.
    m = params.k_degree

    # Build two separate BA networks
    grey_ids  = _sspread_build_ba!(net, rng, 1, params.n_greys, m, 0)
    green_ids = _sspread_build_ba!(net, rng, params.n_greys + 1, params.n_greens, min(m, params.n_greens - 1), 1)

    # Inter-group links: NetLogo uses create-links-with <agentset>, meaning each agent
    # that passes the probability check creates links to ALL members of the other group.
    # ask AgentBs [ if random-float 1 < group-openness [create-links-with AgentAs] ]
    for gri in green_ids
        if rand(rng) < params.group_openness
            for gi in grey_ids
                _sspread_add_edge!(net, gri, gi)
            end
        end
    end
    # ask AgentAs [ if random-float 1 < group-openness [create-links-with AgentBs] ]
    for gi in grey_ids
        if rand(rng) < params.group_openness
            for gri in green_ids
                _sspread_add_edge!(net, gi, gri)
            end
        end
    end

    # Community detection via Louvain (matches NetLogo nw:louvain-communities)
    _sspread_louvain!(net, rng)

    # Set edge weights: intra-community = 2, inter-community = 1
    for i in 1:net.n_agents
        for j in net.adj[i]
            w = (net.community[i] == net.community[j]) ? 2 : 1
            net.weight[i][j] = w
        end
    end

    # Hub-weak: NetLogo selects turtles with degree > max-degree - 10, sets all their links to weight 1
    if params.hub_weak
        max_degree = maximum(net.degree[i] for i in 1:net.n_agents)
        for i in 1:net.n_agents
            if net.degree[i] > max_degree - 10
                for j in net.adj[i]
                    net.weight[i][j] = 1
                    net.weight[j][i] = 1
                end
            end
        end
    end

    # Hardliners: 10% of each group
    n_hard_grey = max(1, round(Int, params.prop_hard * params.n_greys))
    n_hard_green = max(1, round(Int, params.prop_hard * params.n_greens))
    shuffle!(rng, grey_ids)
    shuffle!(rng, green_ids)
    for k in 1:min(n_hard_grey, length(grey_ids))
        net.hardliner[grey_ids[k]] = true
    end
    for k in 1:min(n_hard_green, length(green_ids))
        net.hardliner[green_ids[k]] = true
    end

    _sspread_update_stats!(net, stats)
    return nothing
end

function _sspread_update_stats!(net::SSpreadNetwork, stats::SSpreadStats)
    n = net.n_agents
    n_green = count(==(1), net.color)
    stats.pct_green = n > 0 ? n_green / n * 100.0 : 0.0
    stats.pct_grey  = n > 0 ? (n - n_green) / n * 100.0 : 0.0
end

# --- Go system ---
struct SSpreadGoSystem <: System end

function update!(::SSpreadGoSystem, world::World)
    params = get_resource(world, SSpreadParams)
    rng    = get_resource(world, RNGResource).rng
    net    = get_resource(world, SSpreadNetwork)
    stats  = get_resource(world, SSpreadStats)

    n = net.n_agents

    # Moving: NetLogo picks one random link and one random turtle, each with 1% chance
    if params.moving && n > 1
        # ask one-of links [ if random-float 100 < 1 [ die ] ]
        edges = Tuple{Int,Int}[]
        for i in 1:n, j in net.adj[i]
            i < j && push!(edges, (i, j))
        end
        if !isempty(edges)
            ei, ej = edges[rand(rng, 1:length(edges))]
            if rand(rng) * 100.0 < 1.0
                _sspread_remove_edge!(net, ei, ej)
            end
        end
        # ask one-of turtles [ if random-float 100 < 1 [ create-link-with one-of other turtles [ set weight random 3 ] ] ]
        turtle = rand(rng, 1:n)
        if rand(rng) * 100.0 < 1.0
            others = [j for j in 1:n if j != turtle]
            if !isempty(others)
                target = others[rand(rng, 1:length(others))]
                w = rand(rng, 0:2)  # random 3 → 0, 1, or 2
                _sspread_add_edge!(net, turtle, target, w)
            end
        end
    end

    # Interaction: ask turtles [ interact-agent ] — asynchronous, shuffled order
    # NetLogo updates color immediately (asynchronous), so later agents see updated colors.
    order = shuffle!(rng, collect(1:n))

    for i in order
        net.hardliner[i] && continue
        isempty(net.adj[i]) && continue

        total_neighbors = length(net.adj[i])

        # NetLogo interact-agent:
        # count-strong = count ALL diff-color neighbors IF agent has ANY strong links
        # count-weak = count ALL diff-color neighbors IF agent has ANY weak links
        has_strong = false
        has_weak = false
        for j in net.adj[i]
            w = get(net.weight[i], j, 1)
            if w >= 2
                has_strong = true
            else
                has_weak = true
            end
        end

        count_diff_color = 0
        for j in net.adj[i]
            if net.color[j] != net.color[i]
                count_diff_color += 1
            end
        end

        count_weak = has_weak ? count_diff_color : 0
        count_strong = has_strong ? count_diff_color : 0

        # Weak tie activation: agents only turn GREEN (no countervailing contagion in NetLogo)
        threshold_weak = params.activation_threshold * total_neighbors + rand(rng, 0:5)
        if count_weak >= threshold_weak
            net.color[i] = 1  # turn green (asynchronous update)
        end

        # Strong tie activation: agents only turn GREEN
        if params.strong_ties
            threshold_s = params.threshold_strong + rand(rng, 0:3)
            if count_strong >= threshold_s
                net.color[i] = 1  # turn green (asynchronous update)
            end
        end
    end

    _sspread_update_stats!(net, stats)
    return nothing
end

# --- Termination ---
struct SSpreadTerminationSystem <: System end

function update!(::SSpreadTerminationSystem, world::World)
    params = get_resource(world, SSpreadParams)
    tick   = get_resource(world, Tick)
    net    = get_resource(world, SSpreadNetwork)

    all_green = all(==(1), net.color)
    all_grey  = all(==(0), net.color)
    if all_green || all_grey || tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
