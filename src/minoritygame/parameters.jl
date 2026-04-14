Base.@kwdef mutable struct MGParams
    number::Int = 501           # number of agents (odd)
    memory::Int = 6             # history length
    strategies_per_agent::Int = 5
    max_ticks::Int = 500
    seed::Int = 42
end
