# Agent traits: boldness (0-7), vengefulness (0-7), accumulated points, seen value
mutable struct NormAgent
    boldness::Int
    vengefulness::Int
    points::Float64
    seen::Float64
end
NormAgent() = NormAgent(0, 0, 0.0, 0.0)
