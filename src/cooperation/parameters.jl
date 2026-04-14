Base.@kwdef mutable struct COOPParams
    initial_cows::Int = 20
    cooperative_probability::Float64 = 0.5
    stride_length::Float64 = 0.08
    metabolism::Float64 = 6.0
    reproduction_threshold::Float64 = 102.0
    reproduction_cost::Float64 = 54.0
    grass_energy::Float64 = 51.0
    low_high_threshold::Int = 5
    high_growth_chance::Float64 = 77.0
    low_growth_chance::Float64 = 30.0
    max_grass_height::Int = 10
    grid_width::Int = 21
    grid_height::Int = 21
    max_ticks::Int = 1000
    seed::Int = 42
end
