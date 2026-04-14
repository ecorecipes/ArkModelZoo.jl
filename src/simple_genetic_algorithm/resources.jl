mutable struct SGAStats
    best_fitness::Float64
    mean_fitness::Float64
    worst_fitness::Float64
    diversity::Float64
end
SGAStats() = SGAStats(0.0, 0.0, 0.0, 0.0)
