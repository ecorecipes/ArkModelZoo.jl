mutable struct SSpreadNetwork
    n_agents::Int
    color::Vector{Int}            # 0 = grey, 1 = green
    hardliner::Vector{Bool}
    community::Vector{Int}        # community label from Louvain detection
    adj::Vector{Set{Int}}
    weight::Vector{Dict{Int,Int}} # edge weights: agent → neighbor → weight
    degree::Vector{Int}
end

function SSpreadNetwork()
    SSpreadNetwork(0, Int[], Bool[], Int[], Set{Int}[], Dict{Int,Int}[], Int[])
end

function _sspread_add_agent!(net::SSpreadNetwork, color::Int)
    push!(net.color, color)
    push!(net.hardliner, false)
    push!(net.community, 0)
    push!(net.adj, Set{Int}())
    push!(net.weight, Dict{Int,Int}())
    push!(net.degree, 0)
    net.n_agents += 1
    return net.n_agents
end

function _sspread_add_edge!(net::SSpreadNetwork, i::Int, j::Int, w::Int=1)
    if j ∉ net.adj[i]
        push!(net.adj[i], j)
        push!(net.adj[j], i)
        net.degree[i] += 1
        net.degree[j] += 1
        net.weight[i][j] = w
        net.weight[j][i] = w
    end
    # NetLogo's create-link-with silently ignores existing links (no weight update)
end

function _sspread_remove_edge!(net::SSpreadNetwork, i::Int, j::Int)
    if j ∈ net.adj[i]
        delete!(net.adj[i], j)
        delete!(net.adj[j], i)
        delete!(net.weight[i], j)
        delete!(net.weight[j], i)
        net.degree[i] -= 1
        net.degree[j] -= 1
    end
end

mutable struct SSpreadStats
    pct_green::Float64
    pct_grey::Float64
end
SSpreadStats() = SSpreadStats(0.0, 0.0)
