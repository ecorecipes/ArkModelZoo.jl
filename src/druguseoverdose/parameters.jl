Base.@kwdef mutable struct DrugUseOverdoseParams
    population_size::Int = 50
    percent_drug_user::Int = 20
    drug_availability::Int = 15
    grid_width::Int = 33    # -16..16 → 33 patches
    grid_height::Int = 33
    max_ticks::Int = 200
    seed::Int = 42
end
