# Continuous position on toroidal grid (NetLogo world -25,25 → [0,51))
mutable struct BRPosition
    x::Float64
    y::Float64
end

# Persistent heading (degrees, 0=north, clockwise)
mutable struct BRHeading
    angle::Float64
end

# Tag components for breed
struct RedTurtle end
struct BlueTurtle end
