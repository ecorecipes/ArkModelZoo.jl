mutable struct WCState
    n_agents::Int
    x::Vector{Float64}
    y::Vector{Float64}
    heading::Vector{Float64}
    belief::Vector{Int}          # 1 (believer) or -1 (disbeliever)
    compliance::Vector{Int}      # 1 or -1
    strength::Vector{Float64}
    complying_for::Vector{Int}
    property::Vector{Symbol}     # :offender, :bystanders, :intervener, :neutralized
    offender_index::Vector{Float64}
    perform_intervention::Vector{Bool}
    my_thresholds::Vector{Float64}
    seriousness::Vector{Float64}
    n_believers::Int
    n_disbelievers::Int
end

function WCState()
    WCState(0,
        Float64[], Float64[], Float64[],
        Int[], Int[], Float64[], Int[],
        Symbol[], Float64[], Bool[], Float64[], Float64[],
        0, 0)
end

mutable struct WCStats
    cnt_offenders::Float64
    cnt_inter::Float64
    cnt_neutralized::Float64
    curr_oi::Float64
end
WCStats() = WCStats(0.0, 0.0, 0.0, 0.0)
