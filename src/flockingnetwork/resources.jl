mutable struct FNStats
    num_links::Int
    avg_heading::Float64
end
FNStats() = FNStats(0, 0.0)
