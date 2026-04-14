Base.@kwdef mutable struct TBParams
    number_of_cars::Int = 20
    acceleration::Float64 = 0.0045
    deceleration::Float64 = 0.026
    road_length::Int = 51        # world-width (from -25 to 25 = 51 patches)
    max_ticks::Int = 200
    seed::Int = 42
end
