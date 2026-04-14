Base.@kwdef mutable struct RadParams
    data_dir::String = "."
    growth::Float64 = 1.5
    num_townships::Int = 9
    num_terrorist_clusters::Int = 5
    link_distance::Float64 = 25.0
    degree::Int = 8
    radicalism_init::Float64 = 1.3
    grid_width::Int = 755
    grid_height::Int = 555
    max_ticks::Int = 50
    seed::Int = 42
end
