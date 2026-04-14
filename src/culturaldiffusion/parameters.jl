Base.@kwdef mutable struct CulturalDiffusionParams
    prob_innov::Float64 = 0.5
    prob_adoption::Float64 = 0.9
    prob_forget::Float64 = 0.0002
    max_lang::Int = 120
    max_capacity::Int = 3
    grid_width::Int = 17    # -8..8 → 17 patches
    grid_height::Int = 17
    max_ticks::Int = 200
    seed::Int = 42
end
