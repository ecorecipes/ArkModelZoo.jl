Base.@kwdef mutable struct SIRParams
    num_people::Int = 200
    initial_infected::Int = 5
    infection_radius::Float64 = 1.5
    infection_chance::Float64 = 0.15
    recovery_time::Int = 14
    grid_width::Int = 33
    grid_height::Int = 33
    max_ticks::Int = 1000
    seed::Int = 42
end
