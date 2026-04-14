mutable struct DLAsPosition
    x::Float64
    y::Float64
end
DLAsPosition() = DLAsPosition(0.0, 0.0)

mutable struct DLAsHeading
    angle::Float64
end
DLAsHeading() = DLAsHeading(0.0)
