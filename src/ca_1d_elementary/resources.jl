mutable struct CA1DGrid
    width::Int
    height::Int
    cells::Matrix{Bool}   # cells[x, row] — row 1 is the top
end

function CA1DGrid(w::Int, h::Int)
    CA1DGrid(w, h, falses(w, h))
end

mutable struct CA1DStats
    current_row::Int
    density_on::Float64
end
CA1DStats() = CA1DStats(1, 0.0)
