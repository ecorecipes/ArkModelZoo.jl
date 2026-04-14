# Directed network for social belief diffusion with weighted links
mutable struct SNDNetwork
    n::Int
    in_links::Vector{Vector{Int}}
    weights::Dict{Tuple{Int,Int},Float64}
    p::Vector{Int}           # 1=red, -1=grey
    oldsum::Vector{Float64}
    utility::Vector{Float64}
end

function SNDNetwork()
    SNDNetwork(0, Vector{Int}[], Dict{Tuple{Int,Int},Float64}(), Int[], Float64[], Float64[])
end

mutable struct SNDStats
    num_red::Int
    num_grey::Int
    avg_utility::Float64
end
SNDStats() = SNDStats(0, 0, 0.0)
