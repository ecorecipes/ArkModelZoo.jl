# Continuous position of a ball on the grid
mutable struct BallPosition
    x::Float64
    y::Float64
end
BallPosition() = BallPosition(0.0, 0.0)
