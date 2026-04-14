# --- Helpers ---

function _recmov_distance(state::RecMovState, i::Int, j::Int)
    dx = state.x[i] - state.x[j]
    dy = state.y[i] - state.y[j]
    return sqrt(dx * dx + dy * dy)
end

function _recmov_build_network!(rng, state::RecMovState, avg_degree::Int)
    n = state.n_agents
    num_links = div(avg_degree * n, 2)
    for _ in 1:num_links
        src = rand(rng, 1:n)
        # Find nearest unlinked agent
        best = 0
        best_dist = Inf
        for j in 1:n
            if j != src && !(j in state.adj[src])
                d = _recmov_distance(state, src, j)
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
    # Ensure single connected component
    _recmov_bridge_components!(rng, state)
end

function _recmov_find_components(state::RecMovState)
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

function _recmov_bridge_components!(rng, state::RecMovState)
    while true
        comps = _recmov_find_components(state)
        length(comps) <= 1 && break
        # Bridge first two components
        a = comps[1][rand(rng, 1:length(comps[1]))]
        b = comps[2][rand(rng, 1:length(comps[2]))]
        push!(state.adj[a], b)
        push!(state.adj[b], a)
    end
end

function _recmov_tally!(state::RecMovState, stats::RecMovStats)
    n = state.n_agents
    ng = count(c -> c == :green, state.color)
    nr = count(c -> c == :red, state.color)
    nb = count(c -> c == :blue, state.color)
    stats.recruitpct = round(100.0 * ng / n, digits=1)
    stats.resistpct  = round(100.0 * nr / n, digits=1)
    stats.neutralpct = round(100.0 * nb / n, digits=1)
end

# --- Systems ---

struct InitRecMovSystem <: System end

function initialize!(::InitRecMovSystem, world::World)
    params = get_resource(world, RecMovParams)
    rng = get_resource(world, RNGResource).rng
    state = get_resource(world, RecMovState)
    stats = get_resource(world, RecMovStats)

    # Create agents at random positions (scaled by 0.90 as in NetLogo)
    # World is -30..30 non-wrapping
    for _ in 1:params.n_of_people
        x = (rand(rng) * 2.0 - 1.0) * 0.90 * 30.0
        y = (rand(rng) * 2.0 - 1.0) * 0.90 * 30.0
        _recmov_add_agent!(state, x, y)
    end

    # Build spatially-clustered network
    _recmov_build_network!(rng, state, params.average_people_degree)

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

    _recmov_tally!(state, stats)
    return nothing
end

struct RecMovGoSystem <: System end

function update!(::RecMovGoSystem, world::World)
    state = get_resource(world, RecMovState)
    stats = get_resource(world, RecMovStats)

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

    _recmov_tally!(state, stats)
    return nothing
end

struct RecMovTerminationSystem <: System end

function update!(::RecMovTerminationSystem, world::World)
    params = get_resource(world, RecMovParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
