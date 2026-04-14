# Grid position (fixed, one turtle per patch)
mutable struct CoordPosition
    x::Int
    y::Int
end
CoordPosition() = CoordPosition(0, 0)

# Norm: true = Norm1, false = Norm2
mutable struct CoordNorm
    norm1::Bool
end
CoordNorm() = CoordNorm(false)

# Payoff accumulated each tick
mutable struct CoordPayoff
    value::Float64
end
CoordPayoff() = CoordPayoff(0.0)
