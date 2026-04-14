# Continuous position (NetLogo coordinates)
mutable struct TMPosition
    x::Float64
    y::Float64
end
TMPosition() = TMPosition(0.0, 0.0)

# Heading in degrees (NetLogo convention: 0=north, 90=east, clockwise)
mutable struct TMHeading
    angle::Float64
end
TMHeading() = TMHeading(0.0)

# Whether the termite is carrying a wood chip
mutable struct TMCarrying
    carrying::Bool
end
TMCarrying() = TMCarrying(false)
