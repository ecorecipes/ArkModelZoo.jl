mutable struct T2LRoad
    length::Int           # x-axis length (wrapping)
    # 2D occupancy: occ[x, row] where row = pycor + 3  (pycor -2..2 → row 1..5)
    occ::Matrix{Entity}
end

function T2LRoad(len::Int)
    T2LRoad(len, fill(zero_entity, len, 5))
end

# pycor ∈ {-2,-1,0,1,2} → row ∈ {1,2,3,4,5}
@inline pycor_to_row(py::Int) = py + 3

mutable struct T2LStats
    mean_speed::Float64
    num_lane_changes::Int
end
T2LStats() = T2LStats(0.0, 0)
