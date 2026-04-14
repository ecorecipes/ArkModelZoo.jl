# --- Helpers ---

function _rec_distance(state::RecState, i::Int, j::Int)
    dx = state.x[i] - state.x[j]
    dy = state.y[i] - state.y[j]
    return sqrt(dx * dx + dy * dy)
end

function _rec_build_network!(rng, state::RecState, avg_degree::Int)
    n = state.n_agents
    num_links = div(avg_degree * n, 2)
    for _ in 1:num_links
        src = rand(rng, 1:n)
        # Find nearest unlinked agent
        best = 0
        best_dist = Inf
        for j in 1:n
            if j != src && !(j in state.adj[src])
                d = _rec_distance(state, src, j)
                if d < best_dist
                    best_dist = d
                    best = j
                end
            end
        end
        if best > 0
            push!(state.adj[src], best)
            push!(state.adj[best], src)
        end
    end
    # Ensure single connected component via BFS
    _rec_bridge_components!(rng, state)
end

function _rec_find_components(state::RecState)
    visited = falses(state.n_agents)
    components = Vector{Vector{Int}}()
    for i in 1:state.n_agents
        if !visited[i]
            comp = Int[]
            stack = Int[i]
            visited[i] = true
            while !isempty(stack)
                node = pop!(stack)
                push!(comp, node)
                for nb in state.adj[node]
                    if !visited[nb]
                        visited[nb] = true
                        push!(stack, nb)
                    end
                end
            end
            push!(components, comp)
        end
    end
    return components
end

function _rec_bridge_components!(rng, state::RecState)
    while true
        comps = _rec_find_components(state)
        length(comps) <= 1 && break
        # Bridge first two components
        a = comps[1][rand(rng, 1:length(comps[1]))]
        b = comps[2][rand(rng, 1:length(comps[2]))]
        push!(state.adj[a], b)
        push!(state.adj[b], a)
    end
end

function _rec_tally!(state::RecState, stats::RecStats)
    n = state.n_agents
    ng = count(c -> c == :green, state.color)
    nr = count(c -> c == :red, state.color)
    nb = count(c -> c == :blue, state.color)
    stats.recruitpct = round(100.0 * ng / n, digits=1)
    stats.resistpct  = round(100.0 * nr / n, digits=1)
    stats.neutralpct = round(100.0 * nb / n, digits=1)
end

# --- Systems ---

struct InitRecSystem <: System end

function initialize!(::InitRecSystem, world::World)
    params = get_resource(world, RecParams)
    rng = get_resource(world, RNGResource).rng
    state = get_resource(world, RecState)
    stats = get_resource(world, RecStats)

    # Create agents at random positions (scaled by 0.90 as in NetLogo)
    for _ in 1:params.n_of_people
        x = (rand(rng) * 2.0 - 1.0) * 0.90 * 16.0
        y = (rand(rng) * 2.0 - 1.0) * 0.90 * 16.0
        _rec_add_agent!(state, x, y)
    end

    # Build spatially-clustered network
    _rec_build_network!(rng, state, params.average_people_degree)

    # NetLogo order: initiators first, then resistance
    # ask n-of N-Initiators peoples [ receive-invitation ]
    all_indices = collect(1:state.n_agents)
    shuffle!(rng, all_indices)
    n_init = min(params.n_initiators, state.n_agents)
    for i in 1:n_init
        state.color[all_indices[i]] = :green
    end

    # setup-resist: ask peoples with [color = blue] [if random 100 <= Resistance-threshold [set color red]]
    for i in 1:state.n_agents
        if state.color[i] == :blue
            if rand(rng, 0:99) <= params.resistance_threshold
                state.color[i] = :red
            end
        end
    end

    _rec_tally!(state, stats)
    return nothing
end

struct RecGoSystem <: System end

function update!(::RecGoSystem, world::World)
    state = get_resource(world, RecState)
    stats = get_resource(world, RecStats)

    # Check stop condition: no blue agent has a green neighbor
    any_spreadable = false
    for i in 1:state.n_agents
        if state.color[i] == :blue
            for nb in state.adj[i]
                if state.color[nb] == :green
                    any_spreadable = true
                    break
                end
            end
        end
        any_spreadable && break
    end

    if !any_spreadable
        get_resource(world, Terminate).stop = true
        return nothing
    end

    # Spread: blue agents with green neighbors become green
    to_convert = Int[]
    for i in 1:state.n_agents
        if state.color[i] == :blue
            for nb in state.adj[i]
                if state.color[nb] == :green
                    push!(to_convert, i)
                    break
                end
            end
        end
    end
    for i in to_convert
        state.color[i] = :green
    end

    _rec_tally!(state, stats)
    return nothing
end

struct RecTerminationSystem <: System end

function update!(::RecTerminationSystem, world::World)
    params = get_resource(world, RecParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
