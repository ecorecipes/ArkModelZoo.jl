Base.@kwdef mutable struct MBeliefParams
    number_turtles::Int = 200
    percentage_of_believers::Float64 = 0.14
    max_ticks::Int = 500
    seed::Int = 42
end
