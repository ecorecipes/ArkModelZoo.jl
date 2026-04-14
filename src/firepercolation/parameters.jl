Base.@kwdef mutable struct FirePercolationParams
    p::Float64 = 0.6
    grid_width::Int = 100
    grid_height::Int = 100
    max_ticks::Int = 100
    seed::Int = 42
end
