mutable struct ContactGrid
    width::Int
    height::Int
    occupied::Matrix{Bool}  # true = occupied (black), false = empty (white)
end
ContactGrid(w, h) = ContactGrid(w, h, falses(w, h))

mutable struct ContactStats
    p_occupied::Float64
end
ContactStats() = ContactStats(0.0)
