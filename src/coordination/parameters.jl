Base.@kwdef mutable struct CoordinationParams
    init_norm1::Float64 = 0.5
    coordination_benefit::Float64 = 1.0
    grid_size::Int = 33          # 33×33 = (-16,16,-16,16)
    max_ticks::Int = 200
    seed::Int = 42
end
