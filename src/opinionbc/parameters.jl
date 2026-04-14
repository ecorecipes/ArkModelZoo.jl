Base.@kwdef mutable struct OpinionBCParams
    num_agents::Int = 1089          # 33x33 patches
    learning_rate::Float64 = 0.3
    confidence_threshold::Float64 = 0.3
    max_ticks::Int = 5000
    seed::Int = 42
end
