mutable struct SOpnGrid
    width::Int
    height::Int
    old_attitude::Matrix{Int}
    new_attitude::Matrix{Int}
end

function SOpnGrid(w::Int, h::Int)
    SOpnGrid(w, h, zeros(Int, w, h), zeros(Int, w, h))
end

mutable struct SOpnStats
    fizz::Float64
    left_freq::Float64
    right_freq::Float64
end
SOpnStats() = SOpnStats(0.0, 0.0, 0.0)
