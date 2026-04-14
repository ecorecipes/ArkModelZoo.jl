# Grid: 93×535 non-wrapping (NL -46..46 × -267..267)
# Offset: grid_x = nlx + 47, grid_y = nly + 268
mutable struct BombGrid
    width::Int
    height::Int
    patch_type::Matrix{Float64}   # walkable > 0, walls = 0
end
function BombGrid(w::Int, h::Int)
    BombGrid(w, h, zeros(w, h))
end

mutable struct BombStats
    arrested_total::Int
end
BombStats() = BombStats(0)
