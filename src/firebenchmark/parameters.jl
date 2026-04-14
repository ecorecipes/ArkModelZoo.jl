Base.@kwdef mutable struct FBParams
    density::Int = 64
    grid_width::Int = 81
    grid_height::Int = 81
    max_ticks::Int = 100
    seed::Int = 42
end
