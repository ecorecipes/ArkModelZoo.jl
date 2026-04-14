Base.@kwdef mutable struct SGAParams
    population_size::Int = 100
    crossover_rate::Float64 = 70.0    # percent
    mutation_rate::Float64 = 0.5      # percent per bit
    chromosome_length::Int = 100      # world-width in NetLogo
    max_ticks::Int = 500
    seed::Int = 42
end
