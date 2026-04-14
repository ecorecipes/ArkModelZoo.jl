mutable struct VoterGrid
    width::Int
    height::Int
    colors::Matrix{Int}  # 0 or 1 (two colors from pcolors list)
end
VoterGrid(w, h) = VoterGrid(w, h, zeros(Int, w, h))

mutable struct VoterStats
    n_colors::Int
end
VoterStats() = VoterStats(0)
