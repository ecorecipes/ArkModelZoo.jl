# Message types: (:ok, sender, value), (:nogood, sender, nogood_list), (:new_neighbor, sender)
const ABTMessage = Tuple{Symbol, Int, Any}

mutable struct ABTState
    n_agents::Int
    value::Vector{Int}                          # current color 0..5
    adj::Vector{Set{Int}}                       # undirected adjacency
    message_queue::Vector{Vector{ABTMessage}}
    local_view::Vector{Dict{Int,Int}}           # agent → (neighbor → value)
    no_goods::Vector{Vector{Dict{Int,Int}}}     # agent → list of nogood constraints
    x::Vector{Float64}
    y::Vector{Float64}
end

function ABTState()
    ABTState(0, Int[], Set{Int}[], Vector{ABTMessage}[], Dict{Int,Int}[], Vector{Dict{Int,Int}}[], Float64[], Float64[])
end

function _abt_add_agent!(state::ABTState, val::Int, x::Float64, y::Float64)
    state.n_agents += 1
    push!(state.value, val)
    push!(state.adj, Set{Int}())
    push!(state.message_queue, ABTMessage[])
    push!(state.local_view, Dict{Int,Int}())
    push!(state.no_goods, Vector{Dict{Int,Int}}())
    push!(state.x, x)
    push!(state.y, y)
    return state.n_agents
end

mutable struct ABTStats
    bad_links::Int
    unhandled_messages::Int
end
ABTStats() = ABTStats(0, 0)
