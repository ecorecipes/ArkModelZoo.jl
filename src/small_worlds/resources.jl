mutable struct SWNetwork
    graph::NwGraph
    node_to_entity::Vector{Entity}
end
SWNetwork() = SWNetwork(NwGraph(), Entity[])

mutable struct SWStats
    clustering_coefficient::Float64
    average_path_length::Float64
    clustering_coefficient_of_lattice::Float64
    average_path_length_of_lattice::Float64
    number_rewired::Int
end
SWStats() = SWStats(0.0, 0.0, 0.0, 0.0, 0)
