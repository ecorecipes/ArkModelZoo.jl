Base.@kwdef mutable struct NormParams
    turtle_count::Int = 20
    metanorm::Bool = true
    max_ticks::Int = 1000
    seed::Int = 42
end
