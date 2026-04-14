# Lassa Virus – ECS components

# Disease states matching NetLogo color-based states
@enum LassaHealthStatus begin
    LassaSusceptible      = 1   # white
    LassaIncubating       = 2   # yellow
    LassaMild             = 3   # orange+2
    LassaSevere           = 4   # red
    LassaImmuneInfectious = 5   # cyan
    LassaImmune           = 6   # lime+1
    LassaDead             = 7   # gray
end

# Shared position component for both breeds
mutable struct LassaPosition
    x::Float64
    y::Float64
end
LassaPosition() = LassaPosition(0.0, 0.0)

mutable struct LassaHeading
    angle::Float64
end
LassaHeading() = LassaHeading(0.0)

# Human-specific components
mutable struct HumanState
    status::LassaHealthStatus
    hours::Int
    human_speed::Float64
end
HumanState() = HumanState(LassaSusceptible, 0, 1.0)

# Rat marker (tag component)
mutable struct RatTag
    _::Bool
end
RatTag() = RatTag(true)
