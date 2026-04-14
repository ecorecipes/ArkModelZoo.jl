Base.@kwdef mutable struct InfoDiffParams
    p_forget::Float64 = 0.18
    p_verify::Float64 = 0.05
    beta::Float64 = 0.50
    alpha::Float64 = 0.30
    n_agents::Int = 100
    ba_m::Int = 3
    max_ticks::Int = 300
    seed::Int = 42
end
