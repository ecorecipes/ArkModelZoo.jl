Base.@kwdef mutable struct GBTParams
    grid_width::Int = 50
    grid_height::Int = 50
    birth_rate_1::Float64 = 6.0  # brush birth rate
    birth_rate_2::Float64 = 2.0  # tree birth rate
    max_ticks::Int = 200
    seed::Int = 42
end
