Base.@kwdef mutable struct CLParams
    num_nodes::Int = 20
    start_wt::Float64 = 0.05
    match_wt::Float64 = 15.0
    start_strat_max::Float64 = 0.3
    base_learn::Float64 = 0.07
    partner_learn::Float64 = 0.07
    max_ticks::Int = 10000
    seed::Int = 42
end
