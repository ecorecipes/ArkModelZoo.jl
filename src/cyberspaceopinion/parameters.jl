Base.@kwdef mutable struct CyberParams
    seed::Int = 42
    grid_size::Int = 51
    recover_rate::Float64 = 0.001
    infection_rate::Float64 = 0.05
    n_extremist_leaders::Int = 5
    threshold_sentiment::Float64 = 0.5
    n_initial_infected::Int = 2
    num_ticks::Int = 200
end
