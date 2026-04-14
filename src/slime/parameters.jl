Base.@kwdef mutable struct SLParams
    population::Int = 400
    sniff_threshold::Float64 = 1.0
    sniff_angle::Float64 = 45.0
    wiggle_angle::Float64 = 40.0
    wiggle_bias::Float64 = 0.0
    evaporation_rate::Float64 = 0.9
    diffusion_rate::Float64 = 1.0
    deposit_amount::Float64 = 2.0
    grid_width::Int = 81    # -40..40
    grid_height::Int = 81
    max_ticks::Int = 300
    seed::Int = 42
end
