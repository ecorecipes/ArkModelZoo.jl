mutable struct MGState
    history::Int              # encoded binary history
    minority::Int             # 0 or 1
    avg_score::Float64
    stdev_score::Float64
    num_picking_zero::Int
end
MGState() = MGState(0, 0, 0.0, 0.0, 0)

mutable struct MGStats
    avg_score::Float64
    stdev_score::Float64
    num_picking_zero::Int
end
MGStats() = MGStats(0.0, 0.0, 0)
