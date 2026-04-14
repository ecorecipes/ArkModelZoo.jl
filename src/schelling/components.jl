mutable struct SchPosition
    x::Int
    y::Int
end
SchPosition() = SchPosition(0, 0)

# true = red, false = blue
mutable struct SchColor
    red::Bool
end
SchColor() = SchColor(true)

mutable struct SchHappiness
    similar_nearby::Int
    other_nearby::Int
    total_nearby::Int
    happy::Bool
end
SchHappiness() = SchHappiness(0, 0, 0, false)
