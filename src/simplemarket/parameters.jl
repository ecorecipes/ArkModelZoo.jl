Base.@kwdef mutable struct SMktParams
    number_of_items::Int = 50
    number_of_traders::Int = 50
    number_of_shoppers::Int = 50
    walking_speed::Float64 = 1.0
    max_ticks::Int = 1000
    seed::Int = 42
end
