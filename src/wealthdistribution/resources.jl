mutable struct WDGrid
    width::Int
    height::Int
    grain_here::Matrix{Float64}
    max_grain_here::Matrix{Float64}
end

function WDGrid(width::Int, height::Int)
    WDGrid(width, height, zeros(Float64, width, height), zeros(Float64, width, height))
end

mutable struct WDStats
    gini_index_reserve::Float64
end
WDStats() = WDStats(0.0)
