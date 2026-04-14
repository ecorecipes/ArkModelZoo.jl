# Patch states: 0=empty(black), 1=grass(green), 2=weeds(violet)
const RGW_EMPTY = Int8(0)
const RGW_GRASS = Int8(1)
const RGW_WEEDS = Int8(2)

mutable struct RGWPatchGrid
    width::Int
    height::Int
    patches::Matrix{Int8}
end
function RGWPatchGrid(w::Int, h::Int)
    RGWPatchGrid(w, h, zeros(Int8, w, h))
end

mutable struct RGWStats
    num_rabbits::Int
    num_grass::Int
    num_weeds::Int
end
RGWStats() = RGWStats(0, 0, 0)
