mutable struct TGCar
    x::Float64
    y::Float64
    speed::Float64
    up_car::Bool       # true=moving south (heading 180), false=moving east (heading 90)
    wait_time::Int
end
TGCar() = TGCar(0.0, 0.0, 0.0, true, 0)
