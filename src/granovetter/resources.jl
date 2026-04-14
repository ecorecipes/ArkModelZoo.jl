mutable struct GRANNetwork
    num_agents::Int
    neighbors::Vector{Vector{Int}}   # adjacency list (1-indexed agent IDs)
end
GRANNetwork(n::Int) = GRANNetwork(n, [Int[] for _ in 1:n])

mutable struct GRANStats
    percent_rioting::Float64
    num_rioting::Int
end
GRANStats() = GRANStats(0.0, 0)
