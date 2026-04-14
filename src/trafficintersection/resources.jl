mutable struct TIRoad
    size::Int
    # Road: patches where |x - center| <= 1 or |y - center| <= 1
    # Signal state
    stop_light::Symbol   # :north or :east (which direction has green)
    # Grid of occupancy
    occupancy::Matrix{Entity}
    # Accident patches: countdown timer (0 = clear)
    accidents::Matrix{Int}
end

function TIRoad(sz::Int)
    TIRoad(sz, :north, fill(zero_entity, sz, sz), zeros(Int, sz, sz))
end

mutable struct TIStats
    waiting_overall::Int
    waiting_eastbound::Int
    waiting_northbound::Int
    num_collisions::Int
end
TIStats() = TIStats(0, 0, 0, 0)
