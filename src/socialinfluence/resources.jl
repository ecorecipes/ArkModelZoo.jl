mutable struct SInflState
    n_agents::Int
    colors::Vector{Int}  # 1=yellow, 2=green
    adj::Vector{Set{Int}}
end

function SInflState()
    SInflState(0, Int[], Set{Int}[])
end

function _sinfl_add_agent!(state::SInflState, color::Int)
    push!(state.colors, color)
    push!(state.adj, Set{Int}())
    state.n_agents += 1
    return state.n_agents
end

mutable struct SInflStats
    number_influence::Int
end
SInflStats() = SInflStats(0)
