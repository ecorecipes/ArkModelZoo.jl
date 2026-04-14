Base.@kwdef mutable struct WolfSheepParams
    initial_number_sheep::Int = 100
    initial_number_wolves::Int = 50
    sheep_gain_from_food::Float64 = 4.0
    wolf_gain_from_food::Float64 = 20.0
    sheep_reproduce::Float64 = 4.0    # percent chance per tick
    wolf_reproduce::Float64 = 5.0     # percent chance per tick
    grass_regrowth_time::Int = 20     # matches NetLogo default
    grass_enabled::Bool = true
    grid_width::Int = 33              # matches NetLogo -16..16
    grid_height::Int = 33
    max_ticks::Int = 1000
    seed::Int = 42
end
