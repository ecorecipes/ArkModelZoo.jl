mutable struct IsingGrid
    width::Int
    height::Int
    spins::Matrix{Int}  # +1 or -1
end
IsingGrid(w, h) = IsingGrid(w, h, ones(Int, w, h))

mutable struct IsingStats
    sum_of_spins::Int
end
IsingStats() = IsingStats(0)
