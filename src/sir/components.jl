# Position on continuous space (NetLogo world -16,16 → [0,33))
mutable struct SIRPosition
    x::Float64
    y::Float64
end

# Persistent heading (degrees, 0=north, clockwise)
mutable struct SIRHeading
    angle::Float64
end

# Days since infection
mutable struct DaysInfected
    days::Int
end

# Tag components for disease state (prefixed to avoid conflict with virus model's @enum)
struct SIRSusceptible end
struct SIRInfected end
struct SIRRecovered end
