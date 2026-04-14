Base.@kwdef mutable struct SocialNetDiffParams
    members::Int = 30
    threshold::Float64 = 0.5
    max_ticks::Int = 20
    seed::Int = 42
end
