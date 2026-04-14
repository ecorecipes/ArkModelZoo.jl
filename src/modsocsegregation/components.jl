mutable struct ModsocPosition
    x::Int
    y::Int
end
ModsocPosition() = ModsocPosition(0, 0)

mutable struct ModsocColor
    yellow::Bool
end
ModsocColor() = ModsocColor(true)

mutable struct ModsocHappiness
    prop_similar::Float64
    happy::Bool
end
ModsocHappiness() = ModsocHappiness(1.0, true)
