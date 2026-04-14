# Agent colors: :green (recruited), :blue (neutral), :red (resister)
mutable struct RecState
    n_agents::Int
    x::Vector{Float64}
    y::Vector{Float64}
    color::Vector{Symbol}        # :green, :blue, :red
    adj::Vector{Set{Int}}
end

function RecState()
    RecState(0, Float64[], Float64[], Symbol[], Set{Int}[])
end

function _rec_add_agent!(state::RecState, x::Float64, y::Float64)
    state.n_agents += 1
    push!(state.x, x)
    push!(state.y, y)
    push!(state.color, :blue)
    push!(state.adj, Set{Int}())
    return state.n_agents
end

mutable struct RecStats
    recruitpct::Float64
    resistpct::Float64
    neutralpct::Float64
end
RecStats() = RecStats(0.0, 0.0, 0.0)
