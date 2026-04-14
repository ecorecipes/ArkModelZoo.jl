# Continuous position on the grid
mutable struct DLAPosition
    x::Float64
    y::Float64
end
DLAPosition() = DLAPosition(0.0, 0.0)

# Heading in degrees (0 = north, 90 = east, NetLogo convention)
mutable struct DLAHeading
    angle::Float64
end
DLAHeading() = DLAHeading(0.0)
