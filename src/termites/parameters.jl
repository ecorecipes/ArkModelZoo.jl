Base.@kwdef mutable struct TMParams
    number::Int = 400          # number of termites
    density::Float64 = 20.0    # percent of patches with wood chips
    grid_width::Int = 201      # -100..100
    grid_height::Int = 201
    max_ticks::Int = 200
    max_steps::Int = 5000      # bound for iterative search loops
    seed::Int = 42
end
