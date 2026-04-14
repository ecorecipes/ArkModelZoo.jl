mutable struct BSitState
    n_agents::Int
    scrip::Vector{Float64}
    scrip_needed::Vector{Float64}
    want_sitter::Vector{Bool}
    want_to_go_out::Vector{Bool}
    enough_scrip::Vector{Bool}
    going_out::Vector{Bool}
    want_to_sit::Vector{Bool}
    sitting::Vector{Bool}
    total_hours_out::Float64
    cycle_pos::Float64
    stop_run::Bool
end

function BSitState()
    BSitState(0, Float64[], Float64[], Bool[], Bool[], Bool[], Bool[], Bool[], Bool[], 0.0, 0.0, false)
end

function _bsit_add_agent!(state::BSitState, initial_scrip::Float64)
    state.n_agents += 1
    push!(state.scrip, initial_scrip)
    push!(state.scrip_needed, 0.0)
    push!(state.want_sitter, false)
    push!(state.want_to_go_out, false)
    push!(state.enough_scrip, false)
    push!(state.going_out, false)
    push!(state.want_to_sit, false)
    push!(state.sitting, false)
    return state.n_agents
end

function _bsit_reset_flags!(state::BSitState)
    n = state.n_agents
    @inbounds for i in 1:n
        state.scrip_needed[i] = 0.0
        state.want_sitter[i] = false
        state.want_to_go_out[i] = false
        state.enough_scrip[i] = false
        state.going_out[i] = false
        state.want_to_sit[i] = false
        state.sitting[i] = false
    end
end

mutable struct BSitStats
    total_scrip::Float64
    max_scrip::Float64
    going_out_count::Int
    sitting_count::Int
    want_sitter_count::Int
    want_to_sit_count::Int
    quiet_evening_count::Int
    no_sitter_count::Int
    no_sitting_jobs_count::Int
    not_enough_scrip_count::Int
    sitting_as_1st_choice_count::Int
    sitting_as_2nd_choice_count::Int
end

function BSitStats()
    BSitStats(0.0, 0.0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
end
