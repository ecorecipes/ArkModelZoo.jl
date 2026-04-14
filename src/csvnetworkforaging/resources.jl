struct CNFNodeData
    id::Int
    x::Int
    y::Int
    capacity::Int
    regrow_rate::Int
end

const CNF_NODES = [
    CNFNodeData(1,-8,-8,40,3), CNFNodeData(2,-4,-4,50,4), CNFNodeData(3,0,0,60,5),
    CNFNodeData(4,4,-4,50,4), CNFNodeData(5,8,-8,40,3), CNFNodeData(6,-8,4,45,3),
    CNFNodeData(7,-4,8,55,5), CNFNodeData(8,0,4,65,6), CNFNodeData(9,4,8,55,5),
    CNFNodeData(10,8,4,45,3), CNFNodeData(11,-6,0,35,2), CNFNodeData(12,6,0,35,2),
]

const CNF_EDGES = [
    (1,2),(2,3),(3,4),(4,5),(1,6),(6,7),(7,8),(8,9),(9,10),
    (2,11),(11,6),(4,12),(12,10),(3,8),(11,3),(12,3),
]

mutable struct CNFNode
    id::Int
    x::Int
    y::Int
    capacity::Int
    supply::Float64
    regrow_rate::Int
    neighbors::Vector{Int}
end

mutable struct CNFConsumer
    energy::Float64
    consumption_rate::Int
    node_idx::Int
    alive::Bool
end

mutable struct CNFNetwork
    nodes::Vector{CNFNode}
    consumers::Vector{CNFConsumer}
end
CNFNetwork() = CNFNetwork(CNFNode[], CNFConsumer[])

mutable struct CNFStats
    total_supply::Float64
    num_consumers::Int
    total_consumed::Float64
end
CNFStats() = CNFStats(0.0, 0, 0.0)
