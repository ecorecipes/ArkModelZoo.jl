Base.@kwdef mutable struct IsingParams
    probability_of_spin_up::Int = 50
    temperature::Float64 = 2.27
    grid_width::Int = 41
    grid_height::Int = 41
    updates_per_tick::Int = 1000
    max_ticks::Int = 1000
    seed::Int = 42
end
