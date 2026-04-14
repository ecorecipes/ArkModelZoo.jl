Base.@kwdef mutable struct CsvPopParams
    n_initial::Int = 30
    grid_xmin::Int = -10
    grid_xmax::Int = 10
    grid_ymin::Int = -10
    grid_ymax::Int = 10
    max_ticks::Int = 100
    seed::Int = 42
end
