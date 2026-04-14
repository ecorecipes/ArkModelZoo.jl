Base.@kwdef mutable struct DatingParams
    population::Int = 88          # 44 blue + 44 green
    grid_size::Int = 33           # 33x33 toroidal
    avg_pickiness::Float64 = 0.0
    avg_timeline::Float64 = 268.0
    avg_commitment::Float64 = 1000.0
    max_ticks::Int = 500
    seed::Int = 42
end
