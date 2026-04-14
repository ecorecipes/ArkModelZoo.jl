Base.@kwdef mutable struct ERParams
    grid_width::Int = 51       # -25..25 => 51 patches (NetLogo -50..50 = 101, reduced for speed)
    grid_height::Int = 51
    bumpy::Bool = true
    hill::Bool = false
    terrain_smoothness::Int = 6
    rainfall::Float64 = 0.1
    soil_hardness::Float64 = 0.8
    max_ticks::Int = 200
    seed::Int = 42
end
