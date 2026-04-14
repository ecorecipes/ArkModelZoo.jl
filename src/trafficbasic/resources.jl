mutable struct TBCar
    x::Float64       # continuous position on the 1D road
    speed::Float64
    speed_limit::Float64
    speed_min::Float64
end

mutable struct TBRoad
    length::Int
    cars::Vector{TBCar}
end
TBRoad(len::Int) = TBRoad(len, TBCar[])

mutable struct TBStats
    mean_speed::Float64
end
TBStats() = TBStats(0.0)
