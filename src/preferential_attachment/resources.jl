mutable struct PANetwork
    graph::NwGraph
    node_to_entity::Vector{Entity}
end
PANetwork() = PANetwork(NwGraph(), Entity[])

mutable struct PAStats
    num_nodes::Int
    num_edges::Int
    max_degree::Int
end
PAStats() = PAStats(0, 0, 0)
