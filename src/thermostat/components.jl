# Heat particle position (continuous, non-wrapping world)
mutable struct ThermoPosition
    x::Float64
    y::Float64
end

# Persistent heading (degrees, 0=north, clockwise)
mutable struct ThermoHeading
    angle::Float64
end
