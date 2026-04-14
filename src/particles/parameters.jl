Base.@kwdef mutable struct ParticlesParams
    num_particles::Int = 50
    speed::Float64 = 0.02
    collision_radius::Float64 = 1.0
    collision_speed::Float64 = 0.1
    grid_width::Int = 33
    grid_height::Int = 33
    max_ticks::Int = 200
    seed::Int = 42
end
