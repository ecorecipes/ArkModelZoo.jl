struct InitTeamSystem <: System end

function initialize!(::InitTeamSystem, world::World)
    params = get_resource(world, TeamAssemblyParams)
    state = get_resource(world, TeamState)
    stats = get_resource(world, TeamStats)

    # Create initial team of team_size agents
    for _ in 1:params.team_size
        idx = _team_add_agent!(state)
        state.in_team[idx] = true
        state.incumbent[idx] = true
    end

    # Tie collaborators: all in-team agents linked to each other
    _team_tie_collaborators!(state)

    # Unmark in-team
    for i in 1:state.n_agents
        state.in_team[i] = false
    end

    # Find components
    stats.giant_component_size = _team_find_giant_component(state)

    return nothing
end

function _team_tie_collaborators!(state::TeamState)
    team_members = Int[]
    for i in 1:state.n_agents
        if state.alive[i] && state.in_team[i]
            push!(team_members, i)
        end
    end
    for i in 1:length(team_members)
        for j in (i+1):length(team_members)
            a, b = team_members[i], team_members[j]
            push!(state.adj[a], b)
            push!(state.adj[b], a)
        end
    end
end

function _team_find_giant_component(state::TeamState)
    explored = falses(state.n_agents)
    giant = 0
    for i in 1:state.n_agents
        if state.alive[i] && !explored[i]
            size = _team_bfs!(state, explored, i)
            if size > giant
                giant = size
            end
        end
    end
    return giant
end

function _team_bfs!(state::TeamState, explored::BitVector, start::Int)
    stack = Int[start]
    explored[start] = true
    count = 0
    while !isempty(stack)
        node = pop!(stack)
        count += 1
        for nb in state.adj[node]
            if state.alive[nb] && !explored[nb]
                explored[nb] = true
                push!(stack, nb)
            end
        end
    end
    return count
end

# --- Main Update System ---

struct TeamGoSystem <: System end

function update!(::TeamGoSystem, world::World)
    params = get_resource(world, TeamAssemblyParams)
    rng = get_resource(world, RNGResource).rng
    state = get_resource(world, TeamState)
    stats = get_resource(world, TeamStats)

    # Mark all alive agents as incumbent
    for i in 1:state.n_agents
        if state.alive[i]
            state.incumbent[i] = true
        end
    end

    # Pick team members
    _team_pick_members!(rng, state, params)

    # Tie collaborators
    _team_tie_collaborators!(state)

    # Age out + unmark in-team
    for i in 1:state.n_agents
        if state.alive[i]
            if state.downtime[i] > params.max_downtime
                state.alive[i] = false
                # Remove from all adjacency lists
                for nb in state.adj[i]
                    delete!(state.adj[nb], i)
                end
                empty!(state.adj[i])
            end
            state.in_team[i] = false
            state.downtime[i] += 1
        end
    end

    # Find components
    stats.giant_component_size = _team_find_giant_component(state)

    return nothing
end

function _team_pick_members!(rng, state::TeamState, params::TeamAssemblyParams)
    for _ in 1:params.team_size
        new_member = 0

        if rand(rng) * 100.0 >= params.p
            # Newcomer
            new_member = _team_add_agent!(state)
        else
            # Try to pick incumbent
            if rand(rng) * 100.0 < params.q
                # Try to pick collaborator of a current team member
                # Find team members who have non-team neighbors
                candidates_source = Int[]
                for i in 1:state.n_agents
                    if state.alive[i] && state.in_team[i]
                        for nb in state.adj[i]
                            if state.alive[nb] && !state.in_team[nb]
                                push!(candidates_source, i)
                                break
                            end
                        end
                    end
                end

                if !isempty(candidates_source)
                    # Pick a non-team neighbor of a random team member with such neighbors
                    src = candidates_source[rand(rng, 1:length(candidates_source))]
                    eligible = Int[]
                    for nb in state.adj[src]
                        if state.alive[nb] && !state.in_team[nb]
                            push!(eligible, nb)
                        end
                    end
                    # NetLogo: "one-of turtles with [not in-team? and (any? link-neighbors with [in-team?])]"
                    # Actually the NetLogo picks from ALL non-team agents who have at least one team neighbor
                    all_eligible = Int[]
                    for i in 1:state.n_agents
                        if state.alive[i] && !state.in_team[i]
                            for nb in state.adj[i]
                                if state.alive[nb] && state.in_team[nb]
                                    push!(all_eligible, i)
                                    break
                                end
                            end
                        end
                    end
                    if !isempty(all_eligible)
                        new_member = all_eligible[rand(rng, 1:length(all_eligible))]
                    else
                        # Fallback: pick any non-team alive agent
                        new_member = _team_pick_any_nonteam(rng, state)
                    end
                else
                    # No team member has non-team neighbors, pick any non-team agent
                    new_member = _team_pick_any_nonteam(rng, state)
                end
            else
                # Pick any non-team alive agent
                new_member = _team_pick_any_nonteam(rng, state)
            end
        end

        if new_member > 0
            state.in_team[new_member] = true
            state.downtime[new_member] = 0
        end
    end
end

function _team_pick_any_nonteam(rng, state::TeamState)
    candidates = Int[]
    for i in 1:state.n_agents
        if state.alive[i] && !state.in_team[i]
            push!(candidates, i)
        end
    end
    if isempty(candidates)
        return 0
    end
    return candidates[rand(rng, 1:length(candidates))]
end

# --- Termination ---

struct TeamTerminationSystem <: System end

function update!(::TeamTerminationSystem, world::World)
    params = get_resource(world, TeamAssemblyParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
