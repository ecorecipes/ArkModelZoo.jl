mutable struct PolymerGrid
    width::Int
    height::Int
    occupancy::Matrix{Int}  # count of turtles per cell
    blue_positions::Vector{Tuple{Int,Int}}
    orange_positions::Vector{Tuple{Int,Int}}
end

function PolymerGrid(w::Int, h::Int)
    PolymerGrid(w, h, zeros(Int, w, h), Tuple{Int,Int}[], Tuple{Int,Int}[])
end

mutable struct PolymerStats
    n_turtles::Int
end
PolymerStats() = PolymerStats(0)
