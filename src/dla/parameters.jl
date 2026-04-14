Base.@kwdef mutable struct DLAParams
    wiggle_angle::Int = 60
    num_particles::Int = 2500
    grid_width::Int = 201
    grid_height::Int = 201
    max_ticks::Int = 1000
    seed::Int = 42
end
