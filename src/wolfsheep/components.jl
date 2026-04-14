# Continuous position on the grid
mutable struct WSPosition
    x::Float64
    y::Float64
end
WSPosition() = WSPosition(0.0, 0.0)

# Energy level (wolves and sheep both have energy)
mutable struct Energy
    energy::Float64
end
Energy() = Energy(0.0)

# Persistent heading (degrees, 0=north, clockwise)
mutable struct WSHeading
    angle::Float64
end
WSHeading() = WSHeading(0.0)

# Tag components for breed dispatch
struct Wolf end
struct Sheep end
