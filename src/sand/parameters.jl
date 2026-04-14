Base.@kwdef mutable struct SandParams
    release_chance::Float64 = 100.0
    density::Int = 10
    spacing::Int = 3
    grid_width::Int = 81
    grid_height::Int = 81
    max_ticks::Int = 200
    seed::Int = 42
end
