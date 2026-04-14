mutable struct DatingState
    n_agents::Int
    x::Vector{Int}
    y::Vector{Int}
    is_blue::Vector{Bool}       # true=blue, false=green
    quality::Vector{Float64}
    pickiness::Vector{Float64}
    timeline::Vector{Int}        # can be negative (NetLogo: round random-normal)
    timeline_count::Vector{Int}
    looking::Vector{Bool}
    partner::Vector{Int}         # 0 = no partner (NetLogo default value)
    has_memory::Vector{Bool}
    consider_single::Vector{Bool}
    relationship_duration::Vector{Int}
    number_partners_ever::Vector{Int}
    # Phase-based fields matching NetLogo's separate ask-turtles blocks
    this_turn_candidate::Vector{Int}          # 0 = "none"
    this_turn_candidate_score::Vector{Float64}
    this_turn_market_assessment::Vector{Float64}
    all_turns_market_assessment::Vector{Float64}
    market_assessment_list::Vector{Vector{Float64}}  # running list for memory agents
end

function DatingState()
    DatingState(0, Int[], Int[], Bool[], Float64[], Float64[], Int[], Int[],
                Bool[], Int[], Bool[], Bool[], Int[], Int[],
                Int[], Float64[], Float64[], Float64[], Vector{Float64}[])
end

function _dating_add_agent!(state::DatingState, x::Int, y::Int, is_blue::Bool,
                            quality::Float64, pickiness::Float64, timeline::Int,
                            has_memory::Bool, consider_single::Bool)
    state.n_agents += 1
    push!(state.x, x)
    push!(state.y, y)
    push!(state.is_blue, is_blue)
    push!(state.quality, quality)
    push!(state.pickiness, pickiness)
    push!(state.timeline, timeline)
    push!(state.timeline_count, 0)
    push!(state.looking, true)
    push!(state.partner, 0)
    push!(state.has_memory, has_memory)
    push!(state.consider_single, consider_single)
    push!(state.relationship_duration, 0)
    push!(state.number_partners_ever, 0)
    push!(state.this_turn_candidate, 0)
    push!(state.this_turn_candidate_score, -100.0)
    push!(state.this_turn_market_assessment, 0.0)
    push!(state.all_turns_market_assessment, 0.0)
    push!(state.market_assessment_list, Float64[0.0, 0.0])  # NetLogo: list 0 0
    return state.n_agents
end

mutable struct DatingGrid
    width::Int
    height::Int
    occupants::Matrix{Vector{Int}}
end

function DatingGrid(w::Int, h::Int)
    occ = Matrix{Vector{Int}}(undef, w, h)
    for i in 1:w, j in 1:h
        occ[i, j] = Int[]
    end
    DatingGrid(w, h, occ)
end

mutable struct DatingStats
    n_paired::Int
end
DatingStats() = DatingStats(0)
