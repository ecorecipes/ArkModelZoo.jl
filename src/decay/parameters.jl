Base.@kwdef mutable struct DecayParams
    decay_chance::Float64 = 3.0
    number_nuclei::Int = 2500
    grid_width::Int = 91
    grid_height::Int = 91
    max_ticks::Int = 1000
    seed::Int = 42
end
