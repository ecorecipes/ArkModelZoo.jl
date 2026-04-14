Base.@kwdef mutable struct ModsocSegParams
    density::Float64 = 0.9
    similarity_threshold::Float64 = 0.3
    grid_width::Int = 33
    grid_height::Int = 33
    max_ticks::Int = 50
    seed::Int = 42
end
