Base.@kwdef mutable struct AntSystemParams
    num_nodes::Int = 10
    num_ants::Int = 15
    as_alpha::Float64 = 1.0
    as_beta::Float64 = 5.0
    as_rho::Float64 = 0.5
    coord_max::Int = 8
    max_ticks::Int = 100
    seed::Int = 42
end
