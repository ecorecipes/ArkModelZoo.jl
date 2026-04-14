# Tourism Destination model – ECS resources

mutable struct TourismStats
    attendance::Int
    reputation::Float64
end
TourismStats() = TourismStats(0, 0.0)

mutable struct TourismState
    attraction::Float64
end
TourismState() = TourismState(300.0)
