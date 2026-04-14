Base.@kwdef mutable struct HBParams
    bug_count::Int = 100
    min_ideal_temp::Float64 = 10.0
    max_ideal_temp::Float64 = 40.0
    min_output_heat::Float64 = 5.0
    max_output_heat::Float64 = 25.0
    evaporation_rate::Float64 = 0.01
    diffusion_rate::Float64 = 0.9
    random_move_chance::Float64 = 0.0   # percent
    grid_width::Int = 100
    grid_height::Int = 100
    max_ticks::Int = 500
    seed::Int = 42
end
