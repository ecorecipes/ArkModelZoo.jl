# Position on continuous space (NetLogo world -16,16 → 33×33, coordinates [0,33))
mutable struct CSIRPosition
    x::Float64
    y::Float64
end

# Persistent heading (degrees, 0=north, clockwise)
mutable struct CSIRHeading
    angle::Float64
end

# Disease state: infected? and immune? booleans (mirrors NetLogo turtles-own)
mutable struct CSIRState
    infected::Bool
    immune::Bool
end
