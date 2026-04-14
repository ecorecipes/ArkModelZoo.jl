# Each agent has a set of strategies and a decision for the current tick
mutable struct ElFarolStrategies
    strategies::Vector{Vector{Float64}}
    best_strategy::Vector{Float64}
end

mutable struct ElFarolDecision
    attend::Bool
    prediction::Float64
end
