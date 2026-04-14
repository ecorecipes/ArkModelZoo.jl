mutable struct ERGrid
    width::Int
    height::Int
    elevation::Matrix{Float64}
    water::Matrix{Float64}
    drain::Matrix{Bool}
end

function ERGrid(w::Int, h::Int)
    ERGrid(w, h, zeros(w, h), zeros(w, h), falses(w, h))
end

mutable struct ERStats
    mean_elevation::Float64
    total_water::Float64
end
ERStats() = ERStats(0.0, 0.0)
