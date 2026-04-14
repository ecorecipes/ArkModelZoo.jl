Base.@kwdef mutable struct HikeParams
    max_ticks::Int = 200
    seed::Int = 42
    data_path::String = ""
end
