Base.@kwdef mutable struct CivGrowthParams
    number_civs::Int = 10
    farm_size_uniform::Bool = false
    SoL_uniform::Bool = true
    grid_width::Int = 65   # -32..32
    grid_height::Int = 65  # -32..32
    max_ticks::Int = 100
    seed::Int = 42
end
