Base.@kwdef mutable struct ResilientParams
    seed::Int = 42
    n_agents::Int = 5
    scale_min::Float64 = 1.0
    scale_max::Float64 = 7.0
    init_value::Float64 = 4.0
    init_rate::Float64 = 0.5
    zipf_values::Vector{Int} = [1, 2, 3, 4, 5, 6, 7]
    zipf_weights::Vector{Float64} = [0.818, 0.143, 0.020, 0.010, 0.005, 0.003, 0.001]
    num_ticks::Int = 200
end
