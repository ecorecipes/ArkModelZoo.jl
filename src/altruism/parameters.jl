Base.@kwdef mutable struct ALTParams
    altruistic_probability::Float64 = 0.26
    selfish_probability::Float64 = 0.26
    benefit_from_altruism::Float64 = 0.48
    cost_of_altruism::Float64 = 0.13
    disease::Float64 = 0.0
    harshness::Float64 = 0.0
    grid_width::Int = 41
    grid_height::Int = 41
    max_ticks::Int = 500
    seed::Int = 42
end
