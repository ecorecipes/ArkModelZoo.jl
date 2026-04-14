mutable struct TICar
    x::Int
    y::Int
    heading::Int     # 0=north, 90=east
    speed::Int
end
TICar() = TICar(0, 0, 0, 0)
