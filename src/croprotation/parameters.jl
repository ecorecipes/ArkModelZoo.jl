Base.@kwdef mutable struct CRParams
    grid_size::Int = 11
    init_nitrogen_mean::Float64 = 10.0
    init_nitrogen_sd::Float64 = 2.0
    fallow_chance::Float64 = 0.05
    low_yield_threshold::Float64 = 0.1
    max_ticks::Int = 200
    seed::Int = 42
end
