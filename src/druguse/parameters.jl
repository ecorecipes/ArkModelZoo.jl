Base.@kwdef mutable struct DrugUseParams
    population_size::Int = 50
    percent_drug_user::Float64 = 20.0
    drug_availability::Int = 5
    grid_size::Int = 33       # 33×33 grid (-16..16)
    max_ticks::Int = 200
    seed::Int = 42
end
