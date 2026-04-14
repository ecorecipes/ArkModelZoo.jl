Base.@kwdef mutable struct BeingGreenParams
    initial_people::Int = 200
    average_locus_of_control::Float64 = 50.0
    average_social_pressure::Float64 = 50.0
    average_sense_of_responsibility::Float64 = 50.0
    average_pbc::Float64 = 20.0
    initial_action_taker_frac::Float64 = 0.10
    grid_width::Int = 33
    grid_height::Int = 33
    max_ticks::Int = 200
    seed::Int = 42
end
