mutable struct COOPGrassGrid
    width::Int
    height::Int
    grass::Matrix{Int}
end

function COOPGrassGrid(width::Int, height::Int)
    COOPGrassGrid(width, height, zeros(Int, width, height))
end

mutable struct COOPStats
    num_cooperative::Int
    num_greedy::Int
    total_cows::Int
end
COOPStats() = COOPStats(0, 0, 0)
