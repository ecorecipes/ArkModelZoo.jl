mutable struct HikePosition
    x::Int
    y::Int
end
HikePosition() = HikePosition(0, 0)

mutable struct HikeState
    steep::Bool
    outbound::Bool
    hike_time_planned::Float64
    hike_time_elapsed::Float64
end
HikeState() = HikeState(false, true, 480.0, 0.0)

struct HikerTag end
