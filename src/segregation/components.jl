# Grid position component
mutable struct GridPosition
    x::Int
    y::Int
end
GridPosition() = GridPosition(0, 0)

# Agent color: true = red, false = green
mutable struct AgentColor
    red::Bool
end
AgentColor() = AgentColor(true)

# Happiness state (computed each tick)
mutable struct Happiness
    similar_nearby::Int
    other_nearby::Int
    total_nearby::Int
    happy::Bool
end
Happiness() = Happiness(0, 0, 0, false)
