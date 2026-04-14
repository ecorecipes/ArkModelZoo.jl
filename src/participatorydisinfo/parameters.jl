Base.@kwdef mutable struct PDisParams
    num_people::Int = 50
    frac_influencers::Float64 = 0.1
    min_size::Int = 2
    max_rumors::Int = 10
    elite_influence::Float64 = 0.05
    social_influence::Float64 = 0.3
    trade_up_influence::Float64 = 0.1
    rumor_generation::Float64 = 0.01
    dissipation_rate::Float64 = 0.005
    heard_rumors_to_generate::Bool = true
    influencers_generate_rumors::Bool = false
    only_one_generates::Bool = false
    only_one_forgets::Bool = false
    model_rate_1_nth::Int = 1
    max_ticks::Int = 200
    seed::Int = 42
end
