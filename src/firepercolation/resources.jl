mutable struct FirePercGrid
    width::Int
    height::Int
    state::Matrix{Int}       # 0=empty, 1=green(tree), 2=red(burned)
    fire_front::Set{Tuple{Int,Int}}
end
FirePercGrid(w, h) = FirePercGrid(w, h, zeros(Int, w, h), Set{Tuple{Int,Int}}())

mutable struct FirePercStats
    fire_size::Int
end
FirePercStats() = FirePercStats(0)
