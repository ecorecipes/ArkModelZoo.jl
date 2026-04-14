mutable struct BoilingGrid
    width::Int
    height::Int
    heat::Matrix{Float64}
end
BoilingGrid(w, h) = BoilingGrid(w, h, zeros(Float64, w, h))

mutable struct BoilingStats
    avg_heat::Float64
end
BoilingStats() = BoilingStats(0.0)
