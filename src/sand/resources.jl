mutable struct SandGrid
    width::Int
    height::Int
    colors::Matrix{Int}       # 0=black, 1=brown, 2=gray, 3=blue
    next_colors::Matrix{Int}
    spout_patches::Vector{Tuple{Int,Int}}  # grid coords of spout patches
end

function SandGrid(w::Int, h::Int)
    SandGrid(w, h, zeros(Int, w, h), zeros(Int, w, h), Tuple{Int,Int}[])
end

mutable struct SandStats
    n_brown::Int
end
SandStats() = SandStats(0)
