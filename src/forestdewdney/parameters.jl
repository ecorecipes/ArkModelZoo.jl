Base.@kwdef mutable struct FDParams
    grid_width::Int = 15
    grid_height::Int = 15
    num_species::Int = 15
    max_ticks::Int = 500
    seed::Int = 42
end
