Base.@kwdef mutable struct RGWParams
    number::Int = 150
    birth_threshold::Float64 = 15.0
    grass_grow_rate::Float64 = 15.0
    weeds_grow_rate::Float64 = 0.0
    grass_energy::Float64 = 5.0
    weed_energy::Float64 = 0.0
    grid_width::Int = 41
    grid_height::Int = 41
    max_ticks::Int = 1000
    seed::Int = 42
end
