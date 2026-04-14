# All climate particles share the same component set.
# Breed: 1=ray, 2=heat, 3=IR, 4=CO2

const BREED_RAY  = 1
const BREED_HEAT = 2
const BREED_IR   = 3
const BREED_CO2  = 4

mutable struct ClimateParticle
    breed::Int
    x::Float64
    y::Float64
    heading::Float64
end
ClimateParticle() = ClimateParticle(BREED_RAY, 1.0, 1.0, 0.0)
