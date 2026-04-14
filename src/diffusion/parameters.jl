Base.@kwdef mutable struct DiffusionParams
    grid_width::Int = 33
    grid_height::Int = 33
    max_ticks::Int = 100
    seed::Int = 42
end
