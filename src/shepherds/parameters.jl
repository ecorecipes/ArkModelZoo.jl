Base.@kwdef mutable struct SHParams
    num_sheep::Int = 150
    num_shepherds::Int = 30
    sheep_speed::Float64 = 0.02
    grid_width::Int = 51    # -25..25 = 51
    grid_height::Int = 51
    max_ticks::Int = 500
    seed::Int = 42
end
