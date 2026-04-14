Base.@kwdef mutable struct ClimateChangeParams
    albedo::Float64 = 0.6
    sun_brightness::Float64 = 1.0
    num_CO2::Int = 0           # CO2 molecules added at setup (0 by default)
    grid_width::Int = 49       # (-24..24)
    grid_height::Int = 31      # (-8..22)
    earth_top_y::Int = 9       # pycor=0 → y=9 in 1-based
    sky_top_y::Int = 26        # pycor=17 → y=26 in 1-based
    max_ticks::Int = 200
    seed::Int = 42
end
