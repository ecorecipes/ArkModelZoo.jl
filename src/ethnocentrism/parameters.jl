Base.@kwdef mutable struct EthnocentrismParams
    mutation_rate::Float64 = 0.005
    death_rate::Float64 = 0.10
    immigrants_per_day::Int = 1
    initial_ptr::Float64 = 0.12
    cost_of_giving::Float64 = 0.01
    gain_of_receiving::Float64 = 0.03
    immigrant_chance_cooperate_same::Float64 = 0.5
    immigrant_chance_cooperate_different::Float64 = 0.5
    grid_size::Int = 50
    max_ticks::Int = 2000
    seed::Int = 42
    start_full::Bool = false  # if true, fill entire grid at start
end
