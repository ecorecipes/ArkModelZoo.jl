Base.@kwdef mutable struct LanguageBordersParams
    initial_percent_green::Float64 = 0.5
    normal_mean::Float64 = 2.0
    grid_width::Int = 41
    grid_height::Int = 41
    max_ticks::Int = 100
    seed::Int = 42
end
