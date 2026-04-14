mutable struct SegregationGrid
    width::Int
    height::Int
    cells::Matrix{Entity}
end

function SegregationGrid(width::Int, height::Int)
    SegregationGrid(width, height, fill(zero_entity, width, height))
end

function is_empty(grid::SegregationGrid, x::Int, y::Int)
    return is_zero(grid.cells[x, y])
end

function set_cell!(grid::SegregationGrid, x::Int, y::Int, eid::Entity)
    grid.cells[x, y] = eid
end

function clear_cell!(grid::SegregationGrid, x::Int, y::Int)
    grid.cells[x, y] = zero_entity
end

mutable struct SegregationStats
    percent_similar::Float64
    percent_unhappy::Float64
    num_unhappy::Int
    num_happy::Int
end
SegregationStats() = SegregationStats(0.0, 0.0, 0, 0)
