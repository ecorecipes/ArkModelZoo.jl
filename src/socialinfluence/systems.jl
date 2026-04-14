struct InitSInflSystem <: System end

function initialize!(::InitSInflSystem, world::World)
    rng = get_resource(world, RNGResource).rng
    state = get_resource(world, SInflState)
    stats = get_resource(world, SInflStats)

    # First node: random color
    color1 = rand(rng, 1:2)
    _sinfl_add_agent!(state, color1)
    stats.number_influence += 1

    # Second node: linked to first, adopts first's color
    _sinfl_add_agent!(state, color1)
    push!(state.adj[1], 2)
    push!(state.adj[2], 1)
    stats.number_influence += 1
    return nothing
end

struct SInflGoSystem <: System end

function update!(::SInflGoSystem, world::World)
    rng = get_resource(world, RNGResource).rng
    state = get_resource(world, SInflState)
    stats = get_resource(world, SInflStats)

    # Find partner: one-of turtles (uniform random)
    partner = rand(rng, 1:state.n_agents)

    # Create new node with random color
    color = rand(rng, 1:2)
    new_id = _sinfl_add_agent!(state, color)

    # Link to partner, adopt partner's color
    push!(state.adj[new_id], partner)
    push!(state.adj[partner], new_id)
    state.colors[new_id] = state.colors[partner]

    stats.number_influence += 1
    return nothing
end

struct SInflTerminationSystem <: System end

function update!(::SInflTerminationSystem, world::World)
    params = get_resource(world, SInflParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
