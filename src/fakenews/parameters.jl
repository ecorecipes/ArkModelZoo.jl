Base.@kwdef mutable struct FNewsParams
    num_agents::Int = 200
    mean_degree::Int = 4
    num_seed_informers::Int = 10
    broadcast_influence::Float64 = 0.01
    influence_rate::Float64 = 0.3
    max_ticks::Int = 100
    seed::Int = 42
end
