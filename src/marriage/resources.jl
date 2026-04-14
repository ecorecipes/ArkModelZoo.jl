mutable struct MarriageState
    man_prefs::Vector{Vector{Int}}      # remaining preference list for each man
    woman_prefs::Vector{Vector{Int}}    # full preference list for each woman
    man_proposal::Vector{Int}           # current proposal target (0 = none)
    woman_accepted::Vector{Int}         # which man each woman accepted (0 = none)
end

function MarriageState(n::Int)
    MarriageState(
        [Int[] for _ in 1:n],
        [Int[] for _ in 1:n],
        zeros(Int, n),
        zeros(Int, n),
    )
end

mutable struct MarriageStats
    num_bachelors::Int
end
MarriageStats() = MarriageStats(0)
