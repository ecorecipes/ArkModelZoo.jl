mutable struct ResilientAgentState
    belief::Vector{Float64}
    belongsafe::Vector{Float64}
    contribute::Vector{Float64}
    hope::Vector{Float64}
    resilience::Vector{Float64}
    strength::Vector{Float64}
    stress::Vector{Float64}
    trusted::Vector{Float64}
    # Rates
    blame_rate::Vector{Float64}
    gratitude_rate::Vector{Float64}
    hope_rate::Vector{Float64}
    listen_rate::Vector{Float64}
    spend_rate::Vector{Float64}
    recovery_rate::Vector{Float64}
    seekhelp_rate::Vector{Float64}
    trust_rate::Vector{Float64}
end

function ResilientAgentState(n::Int, init_val::Float64, init_rate::Float64)
    return ResilientAgentState(
        fill(init_val, n), fill(init_val, n), fill(init_val, n), fill(init_val, n),
        fill(init_val, n), fill(init_val, n), fill(init_val, n), fill(init_val, n),
        fill(init_rate, n), fill(init_rate, n), fill(init_rate, n), fill(init_rate, n),
        fill(init_rate, n), fill(init_rate, n), fill(init_rate, n), fill(init_rate, n),
    )
end

mutable struct ResilientRelationState
    # Numerator variables (N_*)
    n_blame::Matrix{Float64}
    n_feedback::Matrix{Float64}
    n_gratitude::Matrix{Float64}
    n_interact_rate::Matrix{Float64}
    n_recrimination::Matrix{Float64}
    n_seekhelp::Matrix{Float64}
    n_spend::Matrix{Float64}
    n_stress::Matrix{Float64}
    n_trust::Matrix{Float64}
    # Decision variables (D_*)
    d_belief::Matrix{Float64}
    d_blame::Matrix{Float64}
    d_gratitude::Matrix{Float64}
    d_hope::Matrix{Float64}
    d_listen::Matrix{Float64}
    d_seekhelp::Matrix{Float64}
    d_spend::Matrix{Float64}
end

function ResilientRelationState(n::Int)
    return ResilientRelationState(
        ones(n, n), ones(n, n), ones(n, n),
        fill(0.5, n, n),
        ones(n, n), ones(n, n), ones(n, n), ones(n, n), ones(n, n),
        ones(n, n), ones(n, n), ones(n, n), ones(n, n), ones(n, n), ones(n, n), ones(n, n),
    )
end

mutable struct ResilientEnvState
    ei_stress::Vector{Float64}
    eg_stress::Float64
end

ResilientEnvState(n::Int) = ResilientEnvState(zeros(n), 0.0)

mutable struct ResilientStats
    mean_stress::Float64
    mean_resilience::Float64
end

ResilientStats() = ResilientStats(0.0, 0.0)
