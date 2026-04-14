mutable struct NormStats
    mean_points::Float64
    sd_points::Float64
    defections::Int
end
NormStats() = NormStats(0.0, 0.0, 0)
