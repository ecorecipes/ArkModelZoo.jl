Base.@kwdef mutable struct ContactProcessParams
    initial_pop::Int = 1800
    p_death::Float64 = 0.607
    grid_width::Int = 50
    grid_height::Int = 50
    max_ticks::Int = 1000
    seed::Int = 42
end
