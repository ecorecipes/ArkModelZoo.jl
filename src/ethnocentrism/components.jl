# Grid position (integer, Von Neumann neighborhood)
mutable struct EthnoPosition
    x::Int
    y::Int
end
EthnoPosition() = EthnoPosition(0, 0)

# Strategy: cooperate-with-same?, cooperate-with-different?
mutable struct Strategy
    cooperate_with_same::Bool
    cooperate_with_different::Bool
end
Strategy() = Strategy(false, false)

# Agent color (1-4)
mutable struct EthnoColor
    color::Int
end
EthnoColor() = EthnoColor(1)

# Potential to reproduce (accumulated through interactions)
mutable struct PTR
    value::Float64
end
PTR() = PTR(0.0)
