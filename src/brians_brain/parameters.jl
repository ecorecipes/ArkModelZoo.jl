Base.@kwdef mutable struct BBParams
    grid_width::Int = 87        # -43..43 = 87 patches
    grid_height::Int = 115      # -57..57 = 115 patches
    initial_density::Float64 = 0.3
    max_ticks::Int = 200
    seed::Int = 42
end
