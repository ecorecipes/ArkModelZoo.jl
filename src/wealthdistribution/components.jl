# Grid position (integer coords, 1-based)
mutable struct WDPosition
    x::Int
    y::Int
end
WDPosition() = WDPosition(1, 1)

# Heading: 0=North, 90=East, 180=South, 270=West
mutable struct WDHeading
    heading::Int
end
WDHeading() = WDHeading(0)

mutable struct WDTurtle
    age::Int
    wealth::Int
    life_expectancy::Int
    metabolism::Int
    vision::Int
end
WDTurtle() = WDTurtle(0, 0, 0, 0, 0)

struct WDTag end
