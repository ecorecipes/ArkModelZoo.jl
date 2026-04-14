Base.@kwdef mutable struct RopeParams
    world_width::Int = 161      # number of points (0..160)
    y_min::Int = -80
    y_max::Int = 80
    friction::Int = 24
    frequency::Int = 10
    amplitude::Int = 30
    max_ticks::Int = 500
end
