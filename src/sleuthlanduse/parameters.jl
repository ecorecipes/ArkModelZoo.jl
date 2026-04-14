Base.@kwdef mutable struct SleuthParams
    data_dir::String = "."
    lobby::Float64 = 1.0
    dispersion::Float64 = 52.0
    newspread::Float64 = 55.0
    spread::Float64 = 26.0
    rounds::Int = 50
    grid_width::Int = 753
    grid_height::Int = 753
    max_ticks::Int = 50
    seed::Int = 42
end
