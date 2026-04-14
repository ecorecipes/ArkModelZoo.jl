# Cell states: 0 = dead (black), 1 = firing (white), 2 = refractory (red)
mutable struct BBGrid
    width::Int
    height::Int
    state::Matrix{Int}
    firing_neighbors::Matrix{Int}
end

function BBGrid(w::Int, h::Int)
    BBGrid(w, h, zeros(Int, w, h), zeros(Int, w, h))
end

mutable struct BBStats
    firing_count::Int
    refractory_count::Int
    dead_count::Int
end
BBStats() = BBStats(0, 0, 0)
