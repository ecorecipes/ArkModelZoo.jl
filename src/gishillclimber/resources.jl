mutable struct GHCGrid
    width::Int
    height::Int
    elev::Matrix{Float64}
    slope_x::Matrix{Float64}
    slope_y::Matrix{Float64}
end
function GHCGrid(w::Int, h::Int)
    GHCGrid(w, h, zeros(w, h), zeros(w, h), zeros(w, h))
end

mutable struct GHCStats
    mean_elevation::Float64
    n_at_peak::Int
end
GHCStats() = GHCStats(0.0, 0)
