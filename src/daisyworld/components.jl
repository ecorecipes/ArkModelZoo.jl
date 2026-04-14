# Position on the grid
mutable struct DaisyPosition
    x::Int
    y::Int
end
DaisyPosition() = DaisyPosition(0, 0)

# Age counter
mutable struct DaisyAge
    age::Int
end
DaisyAge() = DaisyAge(0)

# Albedo (reflectivity): white ~0.75, black ~0.25
mutable struct Albedo
    value::Float64
end
Albedo() = Albedo(0.5)

# Tag components for daisy types
struct WhiteDaisy end
struct BlackDaisy end
