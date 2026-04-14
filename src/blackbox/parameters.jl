Base.@kwdef mutable struct BBoxParams
    grid_size::Int = 20    # 0..19 = 20x20
    max_ticks::Int = 500
    seed::Int = 42
end
