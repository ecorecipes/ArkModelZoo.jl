Base.@kwdef mutable struct BayesianParams
    initial_prior::Float64 = 0.1
    false_positive_rate::Float64 = 0.05
    power::Float64 = 0.5
    true_hypothesis::Bool = false
    max_ticks::Int = 200
    seed::Int = 42
end
