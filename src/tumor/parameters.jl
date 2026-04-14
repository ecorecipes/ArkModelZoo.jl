Base.@kwdef mutable struct TumorParams
    grid_width::Int = 103       # -51..51
    grid_height::Int = 103
    max_ticks::Int = 1000
    seed::Int = 42
end
