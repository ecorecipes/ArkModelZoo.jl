Base.@kwdef mutable struct PDSimpleParams
    init_coop_freq::Float64 = 0.5
    payoff_benefit::Float64 = 1.0
    payoff_cost::Float64 = 0.1
    grid_size::Int = 33   # 33x33 grid (-16,16,-16,16)
    max_ticks::Int = 200
    seed::Int = 42
end
