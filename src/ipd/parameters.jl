Base.@kwdef mutable struct IPDParams
    p_mutate::Float64 = 0.01
    grid_size::Int = 50   # 50x50 grid
    max_ticks::Int = 200
    seed::Int = 42
end
