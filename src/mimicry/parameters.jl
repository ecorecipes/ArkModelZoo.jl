Base.@kwdef mutable struct MimicryParams
    n_monarchs_init::Int = 225
    n_viceroys_init::Int = 225
    n_birds_init::Int = 75
    carrying_capacity_monarchs::Int = 225
    carrying_capacity_viceroys::Int = 225
    memory_duration::Int = 30
    mutation_rate::Float64 = 5.0        # percent
    memory_size::Int = 3
    reproduction_chance::Float64 = 4.0  # percent
    grid_width::Int = 41                # -20..20
    grid_height::Int = 41
    max_ticks::Int = 1000
    seed::Int = 42
end
