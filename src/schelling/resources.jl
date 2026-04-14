mutable struct SchGrid
    width::Int
    height::Int
    cells::Matrix{Entity}
end

function SchGrid(w::Int, h::Int)
    SchGrid(w, h, fill(zero_entity, w, h))
end

function _sch_is_empty(grid::SchGrid, x::Int, y::Int)
    return is_zero(grid.cells[x, y])
end

function _sch_set_cell!(grid::SchGrid, x::Int, y::Int, eid::Entity)
    grid.cells[x, y] = eid
end

function _sch_clear_cell!(grid::SchGrid, x::Int, y::Int)
    grid.cells[x, y] = zero_entity
end

mutable struct SchStats
    percent_similar::Float64
    percent_unhappy::Float64
end
SchStats() = SchStats(0.0, 0.0)
