mutable struct HBGrid
    width::Int
    height::Int
    cells::Matrix{Entity}      # bug occupancy
    temp::Matrix{Float64}      # patch temperatures
end

function HBGrid(w::Int, h::Int)
    HBGrid(w, h, fill(zero_entity, w, h), zeros(Float64, w, h))
end

function hb_is_empty(grid::HBGrid, x::Int, y::Int)
    is_zero(grid.cells[x, y])
end

mutable struct HBStats
    mean_unhappiness::Float64
    max_unhappiness::Float64
end
HBStats() = HBStats(0.0, 0.0)
