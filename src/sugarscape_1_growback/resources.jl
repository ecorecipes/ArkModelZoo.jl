mutable struct S1GGrid
    width::Int
    height::Int
    psugar::Matrix{Float64}
    max_psugar::Matrix{Float64}
    occupant::Matrix{Entity}
end

function S1GGrid(w::Int, h::Int)
    S1GGrid(w, h, zeros(w, h), zeros(w, h), fill(zero_entity, w, h))
end

mutable struct S1GStats
    population::Int
    mean_sugar::Float64
    max_sugar::Float64
    min_sugar::Float64
end
S1GStats() = S1GStats(0, 0.0, 0.0, 0.0)
