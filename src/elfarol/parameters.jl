Base.@kwdef mutable struct ElFarolParams
    num_agents::Int = 100
    memory_size::Int = 5
    number_strategies::Int = 10
    overcrowding_threshold::Int = 60
    max_ticks::Int = 1000
    seed::Int = 42
end
