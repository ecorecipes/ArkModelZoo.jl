Base.@kwdef mutable struct CrystallizationParams
    room_temp::Float64 = 20.0
    init_metal_temp::Float64 = 1550.0
    melting_temp::Float64 = 500.0
    metal_size::Int = 31  # 31x31 metal block
    max_ticks::Int = 200
    seed::Int = 42
end
