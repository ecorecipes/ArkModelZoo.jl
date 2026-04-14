Base.@kwdef mutable struct DisBitParams
    num_people::Int = 100
    frac_influencers::Float64 = 0.1
    network_type::String = "preferential"
    network_density::Float64 = 0.1
    min_size::Int = 1
    neighborhood_size::Int = 4
    max_rumors::Int = 10
    elite_influence::Float64 = 0.6
    social_influence::Float64 = 0.1
    trade_up_influence::Float64 = 0.1
    rumor_generation::Float64 = 0.05
    initial_green_pct::Int = 50
    variant::String = "irregular"
    ticks_to_end::Int = 3000
    model_rate_1_nth::Int = 1
    heard_rumors_to_generate::Bool = true
    influencers_generate_rumors::Bool = false
    only_one_generates::Bool = true
    only_one_forgets::Bool = false
    dissipation_rate::Float64 = 0.1
    max_ticks::Int = 200
    seed::Int = 42
end
