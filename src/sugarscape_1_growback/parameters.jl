Base.@kwdef mutable struct S1GParams
    initial_population::Int = 400
    grid_width::Int = 50          # 0..49 = 50 patches
    grid_height::Int = 50
    max_ticks::Int = 200
    seed::Int = 42
end
