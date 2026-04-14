mutable struct DLAsGrid
    width::Int
    height::Int
    cluster::Matrix{Bool}
end
DLAsGrid(w::Int, h::Int) = DLAsGrid(w, h, falses(w, h))

mutable struct DLAsStats
    n_remaining::Int
end
DLAsStats() = DLAsStats(0)
