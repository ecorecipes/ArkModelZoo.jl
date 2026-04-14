mutable struct SAttGrid
    width::Int
    height::Int
    old_attitude::Matrix{Int}
    new_attitude::Matrix{Int}
end

function SAttGrid(w::Int, h::Int)
    SAttGrid(w, h, zeros(Int, w, h), zeros(Int, w, h))
end

mutable struct SAttStats
    fizz::Float64
    left_freq::Float64
    right_freq::Float64
end
SAttStats() = SAttStats(0.0, 0.0, 0.0)
