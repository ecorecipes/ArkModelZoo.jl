mutable struct TMGrid
    width::Int
    height::Int
    chips::Matrix{Bool}   # true = wood chip present at this patch
end

function TMGrid(width::Int, height::Int)
    TMGrid(width, height, fill(false, width, height))
end

function tm_has_chip(grid::TMGrid, gx::Int, gy::Int)
    return grid.chips[gx, gy]
end

function tm_place_chip!(grid::TMGrid, gx::Int, gy::Int)
    grid.chips[gx, gy] = true
end

function tm_remove_chip!(grid::TMGrid, gx::Int, gy::Int)
    grid.chips[gx, gy] = false
end

mutable struct TMStats
    num_chip_patches::Int   # total chips on ground
    num_carrying::Int       # termites currently carrying a chip
end
TMStats() = TMStats(0, 0)
