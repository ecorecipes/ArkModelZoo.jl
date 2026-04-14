mutable struct TGCar
    x::Int
    y::Int
    speed::Float64
    up_car::Bool       # true=moving south (down), false=moving east
    wait_time::Int
end
TGCar() = TGCar(0, 0, 0.0, true, 0)
