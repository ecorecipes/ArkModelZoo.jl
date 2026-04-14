Base.@kwdef mutable struct SOpnParams
    influence::String = "linear"
    max_entrench::Int = 3
    init_attitude::Int = 2
    opinion_amplification::Float64 = 0.1
    rnd_initial::Bool = true
    positive_to_negative_ratio::Float64 = 0.5
    radius_size::Int = 20
    grid_xmin::Int = -5
    grid_xmax::Int = 5
    grid_ymin::Int = -5
    grid_ymax::Int = 5
    max_ticks::Int = 50
    seed::Int = 42
end
