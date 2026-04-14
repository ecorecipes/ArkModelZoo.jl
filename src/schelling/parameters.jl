Base.@kwdef mutable struct SchParams
    density::Float64 = 70.0
    pct_similar_wanted::Float64 = 30.0
    grid_width::Int = 51
    grid_height::Int = 51
    max_ticks::Int = 100
    seed::Int = 42
end
