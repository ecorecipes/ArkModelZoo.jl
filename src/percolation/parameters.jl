Base.@kwdef mutable struct PERCParams
    porosity::Float64 = 60.5    # percent chance oil enters a brown cell
    grid_width::Int = 150       # 0..149
    grid_height::Int = 221      # 0..220
    max_ticks::Int = 2000
    seed::Int = 42
end
