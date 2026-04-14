Base.@kwdef mutable struct ContagionSIParams
    num_turtles::Int = 300
    init_infected::Int = 3
    speed::Float64 = 0.5
    turning_angle::Int = 60
    transmissibility::Float64 = 0.01
    spontaneous_infect::Float64 = 0.0
    grid_width::Int = 33
    grid_height::Int = 33
    max_ticks::Int = 200
    seed::Int = 42
end
