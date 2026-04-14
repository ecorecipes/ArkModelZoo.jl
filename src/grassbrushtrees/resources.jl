mutable struct GBTGrid
    width::Int
    height::Int
    types::Matrix{Int}  # 0=grass, 1=brush, 2=tree
end
GBTGrid(w, h) = GBTGrid(w, h, zeros(Int, w, h))

mutable struct GBTStats
    n_trees::Int
end
GBTStats() = GBTStats(0)
