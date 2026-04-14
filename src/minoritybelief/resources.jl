mutable struct MBeliefState
    n_agents::Int
    belief::Vector{Int}          # 0 (cyan/white), 1 (yellow), 2 (magenta/constant)
    is_constant::Vector{Bool}
    adj::Vector{Set{Int}}
    color::Vector{Int}           # 0=cyan, 1=yellow, 2=magenta, 3=white
end

function MBeliefState()
    MBeliefState(0, Int[], Bool[], Set{Int}[], Int[])
end

function _mbelief_add_agent!(state::MBeliefState)
    state.n_agents += 1
    push!(state.belief, 0)
    push!(state.is_constant, false)
    push!(state.adj, Set{Int}())
    push!(state.color, 0)  # cyan by default
    return state.n_agents
end

mutable struct MBeliefStats
    n_magenta::Int
    n_yellow::Int
    n_cyan::Int
end
MBeliefStats() = MBeliefStats(0, 0, 0)
