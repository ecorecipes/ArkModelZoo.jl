Base.@kwdef mutable struct PMktParams
    number_of_people::Int = 100
    sponsor_apple::Int = 5
    sponsor_samsung::Int = 5
    popularity_apple::Float64 = 50.0
    popularity_samsung::Float64 = 50.0
    max_ticks::Int = 200
    seed::Int = 42
end
