mutable struct TSPGraph
    num_nodes::Int
    node_x::Vector{Float64}
    node_y::Vector{Float64}
    cost::Matrix{Int}
    pheromone::Matrix{Float64}
end

function TSPGraph(n::Int)
    TSPGraph(n, zeros(Float64, n), zeros(Float64, n),
             zeros(Int, n, n), zeros(Float64, n, n))
end

mutable struct TSPState
    best_tour::Vector{Int}
    best_tour_cost::Int
end
TSPState() = TSPState(Int[], typemax(Int))

mutable struct TSPStats
    best_tour_cost::Int
end
TSPStats() = TSPStats(typemax(Int))
