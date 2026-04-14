mutable struct LFGrid
    width::Int
    height::Int
    cells::Matrix{Bool}       # living state
    neighbors::Matrix{Int}    # live neighbor count (scratch buffer)
end

function LFGrid(w::Int, h::Int)
    LFGrid(w, h, fill(false, w, h), fill(0, w, h))
end

mutable struct LFStats
    living_count::Int
    density::Float64
end
LFStats() = LFStats(0, 0.0)
