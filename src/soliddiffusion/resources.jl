mutable struct SDGrid
    width::Int
    height::Int
    cells::Matrix{Int}  # 0=empty, 1=green, 2=blue
end
SDGrid(w::Int, h::Int) = SDGrid(w, h, zeros(Int, w, h))

mutable struct SDStats
    n_turtles::Int
end
SDStats() = SDStats(0)
