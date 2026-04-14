Base.@kwdef mutable struct FireParams
    density::Float64 = 57.0      # percent chance each patch has a tree
    grid_width::Int = 251        # -125..125 = 251 patches
    grid_height::Int = 251
    max_ticks::Int = 200
    seed::Int = 42
end
