mutable struct FBGrid
    width::Int
    height::Int
    tree::Matrix{Bool}
    heat::Matrix{Int}
    next_fire::Matrix{Bool}
    fire_front::Matrix{Bool}   # only the newest burning front spreads fire
end

function FBGrid(w::Int, h::Int)
    FBGrid(w, h, falses(w, h), zeros(Int, w, h), falses(w, h), falses(w, h))
end

mutable struct FBStats
    initial_trees::Int
    burned_trees::Int
    burning_count::Int
end
FBStats() = FBStats(0, 0, 0)
