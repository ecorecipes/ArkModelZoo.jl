Base.@kwdef mutable struct PDEParams
    initial_cooperation::Float64 = 66.6   # percent of patches that cooperate initially
    defection_award::Float64 = 1.59       # multiplier for defectors
    grid_width::Int = 101                 # -50..50 = 101 patches
    grid_height::Int = 101
    max_ticks::Int = 200
    seed::Int = 42
end
