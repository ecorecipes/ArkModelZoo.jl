Base.@kwdef mutable struct ContagionSIRParams
    num_turtles::Int = 500
    init_infected::Int = 3
    speed::Float64 = 1.0
    turning_angle::Int = 360
    transmissibility::Float64 = 0.1
    spontaneous_infect::Float64 = 0.0
    recovery_rate::Float64 = 0.01
    remove_recovered::Bool = false
    grid_width::Int = 33
    grid_height::Int = 33
    max_ticks::Int = 200
    seed::Int = 42
end
