mutable struct S1GAgent
    x::Int
    y::Int
    sugar::Float64
    metabolism::Int
    vision::Int
end
S1GAgent() = S1GAgent(0, 0, 0.0, 1, 1)
