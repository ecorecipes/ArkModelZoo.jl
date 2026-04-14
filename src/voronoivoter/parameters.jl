Base.@kwdef mutable struct VoronoiVoterParams
    n_points::Int = 500
    n_palette::Int = 8
    grid_size::Int = 201   # 201×201 grid (-100..100)
    max_ticks::Int = 1000
    seed::Int = 42
end
