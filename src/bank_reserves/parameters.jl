Base.@kwdef mutable struct BRESParams
    people::Int = 57
    reserves::Float64 = 52.0  # reserve ratio percent
    grid_width::Int = 17
    grid_height::Int = 17
    rich_threshold::Int = 10
    max_ticks::Int = 600  # 200 full cycles of 3
    seed::Int = 42
end
