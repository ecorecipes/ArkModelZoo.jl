mutable struct SLPosition
    x::Float64
    y::Float64
end
SLPosition() = SLPosition(0.0, 0.0)

mutable struct SLHeading
    heading::Float64
end
SLHeading() = SLHeading(0.0)
