Base.@kwdef mutable struct AntsParams
    population::Int = 125
    diffusion_rate::Float64 = 50.0    # 0-99, percentage
    evaporation_rate::Float64 = 10.0  # 0-99, percentage
    grid_size::Int = 71               # width and height (odd for center nest)
    max_ticks::Int = 1000
    seed::Int = 42
end
