Base.@kwdef mutable struct RMParams
    grid_width::Int = 101         # -50..50
    grid_height::Int = 101
    eight_mode::Bool = false      # false = neighbors4, true = neighbors8
    seed_one::Bool = true         # true = seed center, false = seed random
    init_clique::Float64 = 0.1   # % for random seeding
    max_ticks::Int = 300
    seed::Int = 42
end
