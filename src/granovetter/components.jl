mutable struct GRANAgent
    id::Int
    threshold::Float64
    riot::Bool
end
GRANAgent() = GRANAgent(0, 0.0, false)
