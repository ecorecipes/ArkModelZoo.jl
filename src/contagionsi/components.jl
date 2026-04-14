# Position on continuous space (NetLogo world -16,16 → [0,33))
mutable struct CIPosition
    x::Float64
    y::Float64
end

# Persistent heading (degrees, 0=north, clockwise)
mutable struct CIHeading
    angle::Float64
end

# Tag components for disease state (CI = Contagion Infection)
struct CISusceptible end
struct CIInfected end
