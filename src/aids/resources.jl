mutable struct AIDSStats
    num_uninfected::Int
    num_infected_unknown::Int
    num_infected_known::Int
    pct_infected::Float64
end
AIDSStats() = AIDSStats(0, 0, 0, 0.0)
