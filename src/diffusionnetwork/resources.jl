# Directed network for idea diffusion with weighted influence links
mutable struct DNNetwork
    n::Int
    in_links::Vector{Vector{Int}}       # in_links[j] = list of nodes i that influence j
    weights::Dict{Tuple{Int,Int},Float64}  # (from, to) => weight
    p::Vector{Int}                       # belief: 1 (red) or -1 (grey)
    oldsum::Vector{Float64}
    utility::Vector{Float64}
end

function DNNetwork()
    DNNetwork(0, Vector{Int}[], Dict{Tuple{Int,Int},Float64}(), Int[], Float64[], Float64[])
end

mutable struct DNStats
    num_red::Int
    num_grey::Int
end
DNStats() = DNStats(0, 0)
