Base.@kwdef mutable struct ParetoLearnParams
    payoff::Matrix{Int} = [3 0; 5 1]
    exploration_rate::Float64 = 0.0
    random_ticks::Int = 400
    max_ticks::Int = 500
    seed::Int = 42
end
