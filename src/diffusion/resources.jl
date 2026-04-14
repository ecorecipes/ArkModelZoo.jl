mutable struct DiffusionGrid
    width::Int
    height::Int
    temp::Matrix{Float64}
end
DiffusionGrid(w, h) = DiffusionGrid(w, h, zeros(Float64, w, h))

mutable struct DiffusionStats
    max_temp::Float64
    mean_temp::Float64
end
DiffusionStats() = DiffusionStats(0.0, 0.0)
