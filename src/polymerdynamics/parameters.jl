Base.@kwdef mutable struct PolymerDynamicsParams
    grid_width::Int = 160
    grid_height::Int = 80
    max_ticks::Int = 200
    seed::Int = 42
end
