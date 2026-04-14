mutable struct BayesianState
    prob_true::Float64
end
BayesianState() = BayesianState(0.0)
