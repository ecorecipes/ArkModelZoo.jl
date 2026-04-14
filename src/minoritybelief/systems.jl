# --- Helpers ---

# Barabási-Albert preferential attachment graph
function _mbelief_build_ba_network!(rng, state::MBeliefState)
    n = state.n_agents
    n < 2 && return
    # Start: nodes 1 and 2 connected
    push!(state.adj[1], 2)
    push!(state.adj[2], 1)
    degree = zeros(Int, n)
    degree[1] = 1
    degree[2] = 1
    total_degree = 2
    for i in 3:n
        # Each new node connects to 1 existing node with prob proportional to degree
        cumsum = 0
        r = rand(rng) * total_degree
        target = 1
        for j in 1:(i-1)
            cumsum += degree[j]
            if cumsum >= r
                target = j
                break
            end
        end
        push!(state.adj[i], target)
        push!(state.adj[target], i)
        degree[i] += 1
        degree[target] += 1
        total_degree += 2
    end
end

function _mbelief_update_counts!(state::MBeliefState, stats::MBeliefStats)
    stats.n_magenta = 0
    stats.n_yellow = 0
    stats.n_cyan = 0
    for i in 1:state.n_agents
        c = state.color[i]
        if c == 2      # magenta
            stats.n_magenta += 1
        elseif c == 1  # yellow
            stats.n_yellow += 1
        elseif c == 0  # cyan
            stats.n_cyan += 1
        end
        # white (3) is not counted by any tracked global
    end
end

# Speak behavior for a single agent
function _mbelief_speak!(rng, state::MBeliefState, i::Int)
    if state.is_constant[i]
        # Constants: ask in-link-neighbors with [breed = opens]
        # NetLogo `and` is non-short-circuit, so random-float 1.0 is always consumed
        for nb in state.adj[i]
            if !state.is_constant[nb]
                rval = rand(rng)
                if state.belief[nb] != 2 && rval < 0.10
                    state.belief[nb] += 1
                    if state.belief[nb] == 2
                        state.color[nb] = 2  # magenta
                    elseif state.belief[nb] == 1
                        state.color[nb] = 1  # yellow
                    end
                end
            end
        end
    else
        b = state.belief[i]
        if b == 2
            # NetLogo: `ask in-link-neighbors with [belief = 1 and belief = 0]`
            # belief = 1 AND belief = 0 is IMPOSSIBLE — this never selects anyone.
            # So opens with belief 2 do nothing when speaking.
            # (consume RNG to match NetLogo's random-float evaluation)
            if rand(rng) < 0.04
                # No neighbors match the impossible condition
            end
        elseif b == 0
            # NetLogo: `ask in-link-neighbors with [belief = 1 and belief = 2]`
            # belief = 1 AND belief = 2 is IMPOSSIBLE — this never selects anyone.
            if rand(rng) < 0.04
                # No neighbors match the impossible condition
            end
        end
    end
end

# Listen behavior for a single agent
# NetLogo iterates through each neighbor's belief sequentially,
# adjusting the listener's belief for each one.
function _mbelief_listen!(rng, state::MBeliefState, i::Int)
    state.is_constant[i] && return
    isempty(state.adj[i]) && return
    rand(rng) >= 0.04 && return
    # NetLogo: let belief_list (list 3)
    # Then prepends each neighbor's belief.
    # Then iterates: for each x, if x=0 and belief!=0 → belief-1; if x=2 and belief!=2 → belief+1
    # The initial 3 in the list never matches x=0 or x=2, so it's a no-op.
    # Build belief_list: start with [3], then prepend each neighbor's belief
    belief_list = Int[3]
    for nb in state.adj[i]
        pushfirst!(belief_list, state.belief[nb])
    end
    for x in belief_list
        if x == 0 && state.belief[i] != 0
            state.belief[i] -= 1
            if state.belief[i] == 0
                state.color[i] = 3  # white
            elseif state.belief[i] == 1
                state.color[i] = 1  # yellow
            end
        end
        if x == 2 && state.belief[i] != 2
            state.belief[i] += 1
            if state.belief[i] == 2
                state.color[i] = 2  # magenta
            elseif state.belief[i] == 1
                state.color[i] = 1  # yellow
            end
        end
    end
end

# --- Systems ---

struct InitMBeliefSystem <: System end

function initialize!(::InitMBeliefSystem, world::World)
    params = get_resource(world, MBeliefParams)
    rng = get_resource(world, RNGResource).rng
    state = get_resource(world, MBeliefState)
    stats = get_resource(world, MBeliefStats)

    # Create agents
    for _ in 1:params.number_turtles
        _mbelief_add_agent!(state)
    end

    # Build BA network
    _mbelief_build_ba_network!(rng, state)

    # Assign initial beliefs: random 0 or 1
    for i in 1:state.n_agents
        state.belief[i] = rand(rng, 0:1)
        # NetLogo: color starts cyan, then if belief=1 → yellow
        if state.belief[i] == 1
            state.color[i] = 1  # yellow
        else
            state.color[i] = 0  # cyan (belief=0)
        end
    end

    # Assign constants (percentage_of_believers fraction)
    n_constants = round(Int, params.percentage_of_believers * params.number_turtles)
    const_indices = randperm(rng, state.n_agents)[1:n_constants]
    for i in const_indices
        state.is_constant[i] = true
        state.belief[i] = 2
        state.color[i] = 2  # magenta
    end

    _mbelief_update_counts!(state, stats)
    return nothing
end

struct MBeliefGoSystem <: System end

function update!(::MBeliefGoSystem, world::World)
    state = get_resource(world, MBeliefState)
    stats = get_resource(world, MBeliefStats)
    rng = get_resource(world, RNGResource).rng

    # NetLogo: ask turtles [...] — shuffled order
    order = randperm(rng, state.n_agents)
    for i in order
        if rand(rng, 0:1) == 1
            _mbelief_speak!(rng, state, i)
            _mbelief_listen!(rng, state, i)
        else
            _mbelief_listen!(rng, state, i)
            _mbelief_speak!(rng, state, i)
        end
    end

    _mbelief_update_counts!(state, stats)

    # Stop if all turtles have color magenta
    all_magenta = all(i -> state.color[i] == 2, 1:state.n_agents)
    if all_magenta
        get_resource(world, Terminate).stop = true
    end

    return nothing
end

struct MBeliefTerminationSystem <: System end

function update!(::MBeliefTerminationSystem, world::World)
    params = get_resource(world, MBeliefParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
