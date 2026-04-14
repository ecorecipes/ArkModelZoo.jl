# Network stored as adjacency list
mutable struct LCNetwork
    neighbors::Vector{Vector{Int}}   # index -> list of neighbor indices
    node_entities::Vector{Entity}    # index -> entity
end
LCNetwork() = LCNetwork(Vector{Int}[], Entity[])

mutable struct LCStats
    mean_state::Float64
    num_grammar_0::Int
    num_grammar_1::Int
end
LCStats() = LCStats(0.0, 0, 0)
