Base.@kwdef mutable struct TGParams
    grid_size_x::Int = 5
    grid_size_y::Int = 5
    num_cars::Int = 200
    speed_limit::Float64 = 1.0
    ticks_per_cycle::Int = 20
    power::Bool = true
    max_ticks::Int = 500
    seed::Int = 42
end
