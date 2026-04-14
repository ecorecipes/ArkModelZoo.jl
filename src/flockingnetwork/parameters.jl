Base.@kwdef mutable struct FlockingNetworkParams
    population::Int = 200
    maximum_separation::Float64 = 3.0
    minimum_separation::Float64 = 1.0
    coupling_strength::Float64 = 0.5
    coherence_strength::Float64 = 0.5
    separation_strength::Float64 = 0.5
    alignment_strength::Float64 = 0.5
    grid_width::Int = 81
    grid_height::Int = 81
    max_ticks::Int = 200
    seed::Int = 42
end
