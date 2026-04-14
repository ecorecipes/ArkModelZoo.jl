mutable struct Coord2GroupID
    id::Int  # 0 or 1
end
Coord2GroupID() = Coord2GroupID(0)

mutable struct Coord2Norm1
    has_norm::Bool
end
Coord2Norm1() = Coord2Norm1(false)

mutable struct Coord2Payoff
    value::Float64
end
Coord2Payoff() = Coord2Payoff(0.0)
