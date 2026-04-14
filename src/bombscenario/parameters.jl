Base.@kwdef mutable struct BombParams
    max_ticks::Int = 50
    seed::Int = 42
    data_path::String = ""
end
