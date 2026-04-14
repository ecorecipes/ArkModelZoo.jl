Base.@kwdef mutable struct DaisyworldParams
    surface_albedo::Float64 = 0.4
    white_albedo::Float64 = 0.75
    black_albedo::Float64 = 0.25
    solar_luminosity::Float64 = 0.8
    start_pct_whites::Float64 = 20.0
    start_pct_blacks::Float64 = 20.0
    max_age::Int = 25
    grid_size::Int = 29
    max_ticks::Int = 500
    seed::Int = 42
    # Ramp scenario: if true, luminosity ramps from 0.2 to 3.0 over max_ticks
    ramp_scenario::Bool = false
end
