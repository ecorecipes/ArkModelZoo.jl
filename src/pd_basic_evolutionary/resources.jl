mutable struct PDEGrid
    width::Int
    height::Int
    cooperate::Matrix{Bool}
    old_cooperate::Matrix{Bool}
    score::Matrix{Float64}
end

function PDEGrid(w::Int, h::Int)
    PDEGrid(w, h, falses(w, h), falses(w, h), zeros(w, h))
end

mutable struct PDEStats
    num_cooperators::Int
    num_defectors::Int
    num_cc::Int   # was C, still C (blue)
    num_dd::Int   # was D, still D (red)
    num_cd::Int   # was C, now D (green)
    num_dc::Int   # was D, now C (yellow)
end
PDEStats() = PDEStats(0, 0, 0, 0, 0, 0)
