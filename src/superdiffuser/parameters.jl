Base.@kwdef mutable struct SDiffParams
    num_agents::Int = 100
    min_links::Int = 2
    percent_adopted_start::Float64 = 0.05
    avg_attitude::Float64 = 2.0
    avg_pers_power::Float64 = 0.25
    avg_pers_one::Float64 = 10.0
    adopt_threshold::Float64 = 5.0
    social_influence::Float64 = 0.05
    status_quo_limit::Int = 50
    max_ticks::Int = 200
    seed::Int = 42
end
