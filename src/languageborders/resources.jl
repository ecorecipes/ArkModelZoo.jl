mutable struct LanguageBordersGrid
    width::Int
    height::Int
    language::Matrix{Float64}
    ability::Matrix{Int}
end

function LanguageBordersGrid(w::Int, h::Int)
    LanguageBordersGrid(w, h, zeros(Float64, w, h), zeros(Int, w, h))
end

mutable struct LanguageBordersStats
    avg_language::Float64
end
LanguageBordersStats() = LanguageBordersStats(0.0)
