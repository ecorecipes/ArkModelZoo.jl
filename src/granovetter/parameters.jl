Base.@kwdef mutable struct GRANParams
    number_of_agents::Int = 20
    network::String = "random"              # "random", "fully connected", "small-world"
    threshold_distribution::String = "normal" # "uniform", "normal"
    number_of_links::Int = 2
    rewire_prop::Float64 = 0.2
    min_threshold::Float64 = 0.0            # for uniform
    max_threshold::Float64 = 75.0           # for uniform
    mean_threshold::Float64 = 25.0          # for normal
    sd_threshold::Float64 = 10.0            # for normal
    max_ticks::Int = 100
    seed::Int = 42
end
