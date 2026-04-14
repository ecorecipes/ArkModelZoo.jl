mutable struct LTechState
    n_agents::Int
    x::Vector{Float64}
    y::Vector{Float64}
    usage::Vector{Vector{String}}
    understanding::Vector{Dict{String,Float64}}
    persistence::Vector{Int}
    teams::Vector{Vector{Int}}
    adj::Vector{Set{Int}}
    influencer::Vector{Int}  # 0=nobody, -1=technology, >0=person ID
    affordances::Dict{String,Int}  # single technology resource
end

function LTechState()
    LTechState(
        0,
        Float64[], Float64[],
        Vector{String}[],
        Dict{String,Float64}[],
        Int[],
        Vector{Int}[],
        Set{Int}[],
        Int[],
        Dict{String,Int}()
    )
end

function _ltech_add_agent!(state::LTechState, x::Float64, y::Float64)
    state.n_agents += 1
    push!(state.x, x)
    push!(state.y, y)
    push!(state.usage, String[])
    push!(state.understanding, Dict{String,Float64}())
    push!(state.persistence, 0)
    push!(state.teams, Int[])
    push!(state.adj, Set{Int}())
    push!(state.influencer, 0)
    return state.n_agents
end

mutable struct LTechStats
    social_influence::Vector{Float64}
    material_influence::Vector{Float64}
    n_users::Int
    n_active::Int
end

LTechStats() = LTechStats(Float64[], Float64[], 0, 0)
