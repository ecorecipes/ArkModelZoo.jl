# Grid tracking patch state: 0=empty, 1=tree(green), 2=burned(black)
mutable struct FireGrid
    width::Int
    height::Int
    state::Matrix{Int}
end
FireGrid(w::Int, h::Int) = FireGrid(w, h, zeros(Int, w, h))

# Tracked globals matching NetLogo
mutable struct FireStats
    initial_trees::Int
    burned_trees::Int
end
FireStats() = FireStats(0, 0)
