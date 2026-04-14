mutable struct CsvPopGrid
    width::Int
    height::Int
    food::Matrix{Float64}
end

function CsvPopGrid(w::Int, h::Int)
    CsvPopGrid(w, h, zeros(Float64, w, h))
end

mutable struct CsvPopAgent
    energy::Float64
    age::Int
    speed::Int
    x::Float64
    y::Float64
    heading::Float64
    alive::Bool
end

mutable struct CsvPopState
    agents::Vector{CsvPopAgent}
end
CsvPopState() = CsvPopState(CsvPopAgent[])

mutable struct CsvPopStats
    total_energy::Float64
    avg_age::Float64
    pop_count::Int
end
CsvPopStats() = CsvPopStats(0.0, 0.0, 0)
