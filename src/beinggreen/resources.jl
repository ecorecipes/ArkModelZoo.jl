mutable struct BeingGreenGrid
    width::Int
    height::Int
    cells::Matrix{Vector{Entity}}
end

function BeingGreenGrid(w::Int, h::Int)
    cells = [Entity[] for _ in 1:w, _ in 1:h]
    BeingGreenGrid(w, h, cells)
end

function clear_grid!(grid::BeingGreenGrid)
    for col in grid.cells
        empty!(col)
    end
end

function pos_to_cell(x::Float64, y::Float64, w::Int, h::Int)
    gx = mod1(round(Int, x), w)
    gy = mod1(round(Int, y), h)
    return gx, gy
end

mutable struct BeingGreenStats
    n_action_takers::Int
end
BeingGreenStats() = BeingGreenStats(0)
