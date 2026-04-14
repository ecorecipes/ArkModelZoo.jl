# Patch type grid: 0=interior, 1=wall(yellow), 2=thermometer(green)
mutable struct ThermoGrid
    width::Int          # 71
    height::Int         # 71
    min_cor::Int        # -35 (min patch coordinate)
    cells::Matrix{Int8}
end

function ThermoGrid(width::Int, height::Int, min_cor::Int)
    ThermoGrid(width, height, min_cor, zeros(Int8, width, height))
end

mutable struct ThermoStats
    temperature::Float64
    temperatures::Vector{Float64}   # rolling window of 10 readings
end
ThermoStats() = ThermoStats(0.0, Float64[])
