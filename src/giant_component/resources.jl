mutable struct GCNetwork
    num_nodes::Int
    adj::Vector{Set{Int}}  # adjacency list: adj[i] = set of neighbors of node i
    num_edges::Int
end
function GCNetwork(n::Int)
    GCNetwork(n, [Set{Int}() for _ in 1:n], 0)
end

mutable struct GCStats
    giant_component_size::Int
    num_edges::Int
    num_components::Int
    fraction_in_giant::Float64
end
GCStats() = GCStats(0, 0, 0, 0.0)
