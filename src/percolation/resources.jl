# Percolation uses a pure grid model (no turtle entities)
# cell states: 0=hard(gray), 1=permeable(brown), 2=leading_edge(red), 3=saturated(black)
const PERC_HARD = 0
const PERC_PERM = 1
const PERC_EDGE = 2
const PERC_SAT  = 3

mutable struct PERCGrid
    width::Int
    height::Int
    cells::Matrix{Int}
    current_row::Int     # which row is the current leading edge (1=top)
    total_oil::Int
end

function PERCGrid(w::Int, h::Int)
    cells = Matrix{Int}(undef, w, h)
    # Checkerboard: (x+y) odd -> permeable(brown), even -> hard(gray)
    for x in 1:w, y in 1:h
        cells[x, y] = (x + y) % 2 == 0 ? PERC_HARD : PERC_PERM
    end
    PERCGrid(w, h, cells, 1, 0)
end

mutable struct PERCStats
    leading_edge_count::Int
    total_oil::Int
end
PERCStats() = PERCStats(0, 0)
