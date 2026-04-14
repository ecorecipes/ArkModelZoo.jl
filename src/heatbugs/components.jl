mutable struct HBPos
    x::Int
    y::Int
end
HBPos() = HBPos(0, 0)

mutable struct HBBug
    ideal_temp::Float64
    output_heat::Float64
    unhappiness::Float64
end
HBBug() = HBBug(0.0, 0.0, 0.0)
