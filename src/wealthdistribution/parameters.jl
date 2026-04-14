Base.@kwdef mutable struct WDParams
    grid_width::Int = 31            # -15..15 → 31
    grid_height::Int = 31
    grain_growth_interval::Int = 1
    life_expectancy_max::Int = 83
    life_expectancy_min::Int = 1
    max_vision::Int = 5
    metabolism_max::Int = 15
    num_grain_grown::Int = 4
    num_people::Int = 250
    percent_best_land::Float64 = 10.0
    max_grain::Int = 50
    max_ticks::Int = 1000
    seed::Int = 42
end
