mutable struct TemperatureGrid
    width::Int
    height::Int
    temperature::Matrix{Float64}
    occupant::Matrix{Entity}
end

function TemperatureGrid(width::Int, height::Int)
    TemperatureGrid(width, height, zeros(Float64, width, height), fill(zero_entity, width, height))
end

mutable struct DaisyStats
    global_temperature::Float64
    num_whites::Int
    num_blacks::Int
    solar_luminosity::Float64
end
DaisyStats() = DaisyStats(0.0, 0, 0, 0.8)
