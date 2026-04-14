mutable struct RMGrid
    width::Int
    height::Int
    times_heard::Matrix{Int}
    first_heard::Matrix{Int}
    just_heard::Matrix{Bool}
end

function RMGrid(w::Int, h::Int)
    RMGrid(w, h, zeros(Int, w, h), fill(-1, w, h), falses(w, h))
end

mutable struct RMStats
    clique::Int
    previous_clique::Int
end
RMStats() = RMStats(0, 0)
