Base.@kwdef mutable struct DiffusionNetworkParams
    members::Int = 100
    threshold::Float64 = 0.5
    max_ticks::Int = 20
    seed::Int = 42
end
