mutable struct FDTree
    x::Int
    y::Int
    species::Int
end

mutable struct FDForest
    width::Int
    height::Int
    trees::Vector{FDTree}
    last_x::Int    # x-cor from NetLogo (position of last killed tree)
    last_y::Int    # y-cor from NetLogo
end

function FDForest(w::Int, h::Int)
    FDForest(w, h, FDTree[], 0, 0)
end

mutable struct FDStats
    local_richness::Int
    sp::Int          # species of last selected candidate
end
FDStats() = FDStats(0, 0)
