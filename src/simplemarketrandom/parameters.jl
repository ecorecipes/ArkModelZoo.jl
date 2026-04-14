Base.@kwdef mutable struct SMktRParams
    number_of_items::Int = 50
    number_of_traders::Int = 20
    number_of_shoppers::Int = 20
    max_ticks::Int = 1000
    seed::Int = 42
end
