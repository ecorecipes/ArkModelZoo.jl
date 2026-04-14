Base.@kwdef mutable struct SegregationParams
    density::Float64 = 95.0         # percent of patches occupied
    pct_similar_wanted::Float64 = 30.0
    grid_width::Int = 25            # -12..12 = 25 patches
    grid_height::Int = 25
    max_ticks::Int = 1000
    seed::Int = 42
end
