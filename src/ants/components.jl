# Ant position on continuous space mapped to grid
mutable struct AntPosition
    x::Float64
    y::Float64
end
AntPosition() = AntPosition(0.0, 0.0)

# Heading in degrees (0 = north, 90 = east)
mutable struct Heading
    angle::Float64
end
Heading() = Heading(0.0)

# Tag: ant is carrying food
struct CarryingFood end

# Ant identity for staggered departure
mutable struct AntID
    who::Int
end
AntID() = AntID(0)
