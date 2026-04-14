Base.@kwdef mutable struct SolidDiffusionParams
    grid_width::Int = 35
    grid_height::Int = 35
    max_ticks::Int = 200
    seed::Int = 42
end
