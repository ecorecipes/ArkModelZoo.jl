mutable struct VoronoiNetwork
    neighbors::Dict{Int, Vector{Int}}  # index-based adjacency
end
VoronoiNetwork() = VoronoiNetwork(Dict{Int, Vector{Int}}())

mutable struct VoronoiGrid
    width::Int
    height::Int
    owner::Matrix{Int}  # which point index owns each patch
end
function VoronoiGrid(w::Int, h::Int)
    VoronoiGrid(w, h, zeros(Int, w, h))
end

mutable struct VoronoiStats
    n_colors::Int
end
VoronoiStats() = VoronoiStats(0)
