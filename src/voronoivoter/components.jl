mutable struct VoterPoint
    x::Float64
    y::Float64
    color_id::Int
end
VoterPoint() = VoterPoint(0.0, 0.0, 1)
