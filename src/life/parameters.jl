Base.@kwdef mutable struct LFParams
    initial_density::Float64 = 35.0  # percent of cells initially alive
    grid_width::Int = 101             # -50..50
    grid_height::Int = 101
    max_ticks::Int = 200
    seed::Int = 42
end
