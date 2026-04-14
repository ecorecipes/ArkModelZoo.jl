# Continuous position on the toroidal grid
mutable struct COOPPosition
    x::Float64
    y::Float64
end
COOPPosition() = COOPPosition(0.0, 0.0)

# Cow breed: cooperative (true) or greedy (false)
mutable struct COOPCowType
    cooperative::Bool
end
COOPCowType() = COOPCowType(true)

# Energy level
mutable struct COOPEnergy
    energy::Float64
end
COOPEnergy() = COOPEnergy(0.0)
