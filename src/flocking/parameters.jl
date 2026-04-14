Base.@kwdef mutable struct FlockingParams
    population::Int = 200
    max_align_turn::Float64 = 5.0
    max_cohere_turn::Float64 = 3.0
    max_separate_turn::Float64 = 1.5
    vision::Float64 = 3.0
    minimum_separation::Float64 = 1.0
    grid_width::Int = 91
    grid_height::Int = 91
    max_ticks::Int = 1000
    seed::Int = 42
end
