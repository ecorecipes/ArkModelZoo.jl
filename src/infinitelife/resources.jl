mutable struct InfLifeGrid
    cells::Set{Tuple{Int,Int}}
end
InfLifeGrid() = InfLifeGrid(Set{Tuple{Int,Int}}())

mutable struct InfLifeStats
    n_cells::Int
end
InfLifeStats() = InfLifeStats(0)
