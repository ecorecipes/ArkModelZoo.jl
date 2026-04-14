Base.@kwdef mutable struct T2LParams
    number::Int = 54
    speed_up::Float64 = 38.0      # acceleration per 1000 ticks
    slow_down::Float64 = 77.0     # deceleration per 1000 ticks
    look_ahead::Int = 1           # 1 or 2 patches ahead
    road_length::Int = 51         # -25..25
    max_ticks::Int = 500
    seed::Int = 42
end
