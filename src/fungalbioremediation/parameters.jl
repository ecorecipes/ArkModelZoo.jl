Base.@kwdef mutable struct FBRParams
    temperature::Float64 = 33.5
    pH::Float64 = 5.0
    fungi_species::String = "Pleurotus Ostreatus"
    initial_fungi::Int = 6
    initial_ecs::Int = 40
    ms::Float64 = 0.5         # mortality speed
    grid_width::Int = 33      # -16..16
    grid_height::Int = 33
    max_ticks::Int = 200
    seed::Int = 42
end
