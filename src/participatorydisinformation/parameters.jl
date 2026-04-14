Base.@kwdef mutable struct PDisinfoParams
    num_people::Int = 50
    frac_influencers::Float64 = 0.1
    max_rumors::Int = 10
    elite_influence::Float64 = 0.6
    social_influence::Float64 = 0.1
    trade_up_influence::Float64 = 0.25
    rumor_generation::Float64 = 0.05
    dissipation_rate::Float64 = 0.1
    max_ticks::Int = 200
    seed::Int = 42
end
