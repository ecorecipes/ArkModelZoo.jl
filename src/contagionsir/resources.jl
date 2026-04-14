mutable struct CSIRStats
    n_infected::Int
    n_immune::Int
end
CSIRStats() = CSIRStats(0, 0)
