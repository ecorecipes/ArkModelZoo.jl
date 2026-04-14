mutable struct CLState
    n_agents::Int
    strategy::Vector{Float64}
    plays::Vector{Int}
    plays_to_99::Vector{Int}
    wins::Vector{Int}
    played::Vector{Bool}
    # Symmetric link weights stored as upper-triangular matrices indexed by (i,j) i<j
    matches_for_choosing::Matrix{Float64}
    matches_real::Matrix{Float64}
end

function CLState()
    CLState(0, Float64[], Int[], Int[], Int[], Bool[],
            Matrix{Float64}(undef, 0, 0), Matrix{Float64}(undef, 0, 0))
end

function _cl_init_agents!(state::CLState, n::Int, rng, start_strat_max::Float64, start_wt::Float64)
    state.n_agents = n
    state.strategy = [rand(rng) * start_strat_max for _ in 1:n]
    state.plays = zeros(Int, n)
    state.plays_to_99 = zeros(Int, n)
    state.wins = zeros(Int, n)
    state.played = falses(n)
    # Fully connected graph — symmetric weight matrices
    state.matches_for_choosing = fill(start_wt, n, n)
    state.matches_real = zeros(Float64, n, n)
    # Zero the diagonal (no self-links)
    for i in 1:n
        state.matches_for_choosing[i, i] = 0.0
    end
    return nothing
end

mutable struct CLStats
    mean_strategy::Float64
    min_strategy::Float64
end

CLStats() = CLStats(0.0, 0.0)
