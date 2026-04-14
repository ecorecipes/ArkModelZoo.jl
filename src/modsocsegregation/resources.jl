mutable struct ModsocGrid
    width::Int
    height::Int
    cells::Matrix{Entity}
end

function ModsocGrid(w::Int, h::Int)
    ModsocGrid(w, h, fill(zero_entity, w, h))
end

mutable struct ModsocStats
    average_similarity::Float64
    unhappiness::Float64
end
ModsocStats() = ModsocStats(0.0, 0.0)
