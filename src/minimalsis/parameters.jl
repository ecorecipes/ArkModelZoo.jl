Base.@kwdef mutable struct MinimalSISParams
    population::Int = 31
    basic_reproduction_number::Int = 2
    max_ticks::Int = 100
    seed::Int = 42
end
