Base.@kwdef mutable struct GHCParams
    max_ticks::Int = 100
    seed::Int = 42
    n_turtles::Int = 100
    grid_size::Int = 51
end
