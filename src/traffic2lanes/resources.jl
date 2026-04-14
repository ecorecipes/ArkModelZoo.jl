mutable struct T2LRoad
    length::Int           # x-axis length
    # Occupancy: lane 0 (y=-2) and lane 1 (y=2)
    lane0::Vector{Entity}  # indexed by x position
    lane1::Vector{Entity}
end

function T2LRoad(len::Int)
    T2LRoad(len, fill(zero_entity, len), fill(zero_entity, len))
end

mutable struct T2LStats
    mean_speed::Float64
    num_lane_changes::Int
end
T2LStats() = T2LStats(0.0, 0)
