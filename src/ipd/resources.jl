mutable struct IPDGrid
    width::Int
    height::Int
    s_number::Matrix{Int}          # 4-bit strategy (0-15)
    previous_outcome::Matrix{Int}  # 0=CC, 1=CD, 2=DC, 3=DD
    recent_score::Matrix{Int}
end

function IPDGrid(w::Int, h::Int)
    IPDGrid(w, h, zeros(Int, w, h), zeros(Int, w, h), zeros(Int, w, h))
end

mutable struct IPDStats
    mean_score::Float64
end
IPDStats() = IPDStats(0.0)
