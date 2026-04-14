mutable struct PDSGrid
    width::Int
    height::Int
    strategy::Matrix{Int}     # 0=defect, 1=cooperate
    payoff::Matrix{Float64}
end

function PDSGrid(w::Int, h::Int)
    PDSGrid(w, h, zeros(Int, w, h), zeros(Float64, w, h))
end

mutable struct PDSStats
    n_cooperators::Int
end
PDSStats() = PDSStats(0)
