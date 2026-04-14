Base.@kwdef mutable struct FFParams
    number::Int = 1500
    cycle_length::Int = 10
    flash_length::Int = 1
    flashes_to_reset::Int = 1
    strategy::Symbol = :delay    # :delay or :advance
    grid_width::Int = 71         # -35..35
    grid_height::Int = 71
    max_ticks::Int = 500
    seed::Int = 42
end
