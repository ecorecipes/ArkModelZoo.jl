mutable struct TeamState
    in_team::Vector{Bool}
    incumbent::Vector{Bool}
    downtime::Vector{Int}
    alive::Vector{Bool}
    adj::Vector{Set{Int}}
    n_agents::Int
end

function TeamState()
    TeamState(Bool[], Bool[], Int[], Bool[], Set{Int}[], 0)
end

function _team_add_agent!(state::TeamState)
    push!(state.in_team, false)
    push!(state.incumbent, false)
    push!(state.downtime, 0)
    push!(state.alive, true)
    push!(state.adj, Set{Int}())
    state.n_agents += 1
    return state.n_agents
end

mutable struct TeamStats
    giant_component_size::Int
end
TeamStats() = TeamStats(0)
