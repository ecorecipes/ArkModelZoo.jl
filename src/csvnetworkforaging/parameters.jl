Base.@kwdef mutable struct CNFParams
    num_consumers::Int = 15
    max_ticks::Int = 150
    seed::Int = 42
end
