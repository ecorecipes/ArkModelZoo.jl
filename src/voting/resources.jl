mutable struct VOTGrid
    width::Int
    height::Int
    vote::Matrix{Int}        # 0 or 1
    total::Matrix{Int}       # sum of neighbor votes
end

function VOTGrid(w::Int, h::Int)
    VOTGrid(w, h, zeros(Int, w, h), zeros(Int, w, h))
end

mutable struct VOTStats
    blue_count::Int    # vote = 1
    green_count::Int   # vote = 0
end
VOTStats() = VOTStats(0, 0)
