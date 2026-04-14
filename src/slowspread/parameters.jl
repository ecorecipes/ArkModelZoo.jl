Base.@kwdef mutable struct SSpreadParams
    n_greys::Int = 200
    n_greens::Int = 20
    k_degree::Int = 6
    group_openness::Float64 = 0.05
    prop_hard::Float64 = 0.1
    activation_threshold::Float64 = 0.75
    threshold_strong::Int = 5
    moving::Bool = true
    strong_ties::Bool = true
    countervailing_contagion::Bool = true
    hub_weak::Bool = true
    max_ticks::Int = 200
    seed::Int = 42
end
