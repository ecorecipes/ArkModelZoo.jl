mutable struct PGStats
    mean_money::Float64
    mean_investment::Float64
    bank::Float64
    turn::Int
end
PGStats() = PGStats(0.0, 0.0, 0.0, 0)
