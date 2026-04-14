mutable struct T2LCar
    x::Int
    pycor::Int             # actual y position: -2..2 (intermediate during lane change)
    lane::Int              # logical lane: 0 or 1
    speed::Float64
    speed_limit::Float64
    patience::Int
    max_patience::Int
    target_lane::Int
    change::Bool
end
T2LCar() = T2LCar(0, -2, 0, 0.0, 1.0, 50, 50, 0, false)
