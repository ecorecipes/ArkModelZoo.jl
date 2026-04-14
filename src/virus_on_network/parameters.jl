Base.@kwdef mutable struct VONParams
    number_of_nodes::Int = 150
    average_node_degree::Int = 6
    initial_outbreak_size::Int = 3
    virus_spread_chance::Float64 = 2.5   # percent
    virus_check_frequency::Int = 1       # ticks
    recovery_chance::Float64 = 5.0       # percent
    gain_resistance_chance::Float64 = 5.0 # percent
    max_ticks::Int = 300
    seed::Int = 42
end
