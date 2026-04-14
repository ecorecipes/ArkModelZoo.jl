# Butterfly / bird position (continuous, toroidal wrapping)
mutable struct MimicryPosition
    x::Float64
    y::Float64
end

# Persistent heading (degrees, 0=north, clockwise)
mutable struct MimicryHeading
    angle::Float64
end

# NetLogo color value (used for mimicry matching)
mutable struct MimicryColor
    color::Float64
end

# Bird memory: list of (color, age) pairs
mutable struct BirdMemory
    memory::Vector{Tuple{Float64, Int}}
end
BirdMemory() = BirdMemory(Tuple{Float64, Int}[])

# Breed tags
struct MonarchTag end
struct ViceroyTag end
struct BirdTag end
