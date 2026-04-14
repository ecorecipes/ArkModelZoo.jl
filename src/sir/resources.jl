mutable struct SIRStats
    num_susceptible::Int
    num_infected::Int
    num_recovered::Int
end
SIRStats() = SIRStats(0, 0, 0)
