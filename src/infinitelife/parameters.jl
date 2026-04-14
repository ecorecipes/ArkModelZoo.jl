Base.@kwdef mutable struct InfLifeParams
    init_min::Int = -16
    init_max::Int = 16
    init_density::Float64 = 0.35
    max_ticks::Int = 20
    seed::Int = 42
end
