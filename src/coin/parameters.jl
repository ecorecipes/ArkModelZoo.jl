Base.@kwdef mutable struct CoinParams
    num_agents::Int = 63
    discount_rate::Float64 = 0.98
    warmup::Int = 100
    max_ticks::Int = 200
    seed::Int = 42
end
