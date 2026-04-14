# Position on continuous space
mutable struct VPosition
    x::Float64
    y::Float64
end
VPosition() = VPosition(0.0, 0.0)

# Heading in degrees (0 = north, clockwise)
mutable struct VHeading
    angle::Float64
end
VHeading() = VHeading(0.0)

# Health state: susceptible, infected, or resistant
@enum VHealthStatus VSusceptible=1 VInfected=2 VResistant=3

mutable struct VirusState
    status::VHealthStatus
end
VirusState() = VirusState(VSusceptible)

# Virus timer (ticks since infection)
mutable struct VirusTimer
    timer::Int
end
VirusTimer() = VirusTimer(0)
