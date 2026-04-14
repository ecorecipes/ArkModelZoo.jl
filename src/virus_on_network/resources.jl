mutable struct VONNetwork
    graph::NwGraph
    node_to_entity::Vector{Entity}
end

VONNetwork() = VONNetwork(NwGraph(), Entity[])

mutable struct VONStats
    num_susceptible::Int
    num_infected::Int
    num_resistant::Int
end
VONStats() = VONStats(0, 0, 0)
