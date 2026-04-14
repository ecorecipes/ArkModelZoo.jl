mutable struct SLChemicalGrid
    width::Int
    height::Int
    chemical::Matrix{Float64}
end

function SLChemicalGrid(width::Int, height::Int)
    SLChemicalGrid(width, height, zeros(Float64, width, height))
end

mutable struct SLStats
    total_chemical::Float64
    max_chemical::Float64
end
SLStats() = SLStats(0.0, 0.0)
