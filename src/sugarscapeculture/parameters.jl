Base.@kwdef mutable struct SCParams
    initial_population::Int = 400
    grid_width::Int = 50
    grid_height::Int = 50
    max_ticks::Int = 200
    seed::Int = 42
end
