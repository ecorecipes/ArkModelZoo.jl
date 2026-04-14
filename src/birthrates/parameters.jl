Base.@kwdef mutable struct BirthRatesParams
    carrying_capacity::Int = 200
    red_fertility::Float64 = 2.0
    blue_fertility::Float64 = 2.0
    grid_width::Int = 51        # NetLogo -25..25 = 51 patches
    grid_height::Int = 51
    max_ticks::Int = 50
    seed::Int = 42
end
