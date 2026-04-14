Base.@kwdef mutable struct TIParams
    freq_north::Float64 = 60.0   # percent chance new car from north
    freq_east::Float64 = 100.0   # percent chance new car from east
    speed_limit::Int = 5
    max_accel::Int = 2
    max_brake::Int = 4
    green_length::Int = 12
    yellow_length::Int = 3
    auto::Bool = true
    grid_size::Int = 35   # -17..17 = 35
    max_ticks::Int = 500
    seed::Int = 42
end
