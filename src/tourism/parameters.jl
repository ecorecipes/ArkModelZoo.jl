# Tourism Destination model – parameters

Base.@kwdef mutable struct TourismParams
    initial_number::Int = 30
    maintaining_rate::Float64 = 80.0
    capacity::Int = 410
    innovative::Bool = false
    promotive::Bool = false
    extension::Bool = false
    max_ticks::Int = 50
    seed::Int = 42
end
