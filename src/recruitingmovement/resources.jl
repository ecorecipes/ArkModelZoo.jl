mutable struct RecMovState
    n_agents::Int
    x::Vector{Float64}
    y::Vector{Float64}
    color::Vector{Symbol}        # :green, :blue, :red
    adj::Vector{Set{Int}}
end

function RecMovState()
    RecMovState(0, Float64[], Float64[], Symbol[], Set{Int}[])
end

function _recmov_add_agent!(state::RecMovState, x::Float64, y::Float64)
    state.n_agents += 1
    push!(state.x, x)
    push!(state.y, y)
    push!(state.color, :blue)
    push!(state.adj, Set{Int}())
    return state.n_agents
end

mutable struct RecMovStats
    recruitpct::Float64
    resistpct::Float64
    neutralpct::Float64
end
RecMovStats() = RecMovStats(0.0, 0.0, 0.0)
