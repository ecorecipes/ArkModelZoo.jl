mutable struct PMktNetwork
    n_agents::Int
    adj::Vector{Set{Int}}
    degree::Vector{Int}
    buy_apple::Vector{Bool}
    buy_samsung::Vector{Bool}
end

function PMktNetwork()
    PMktNetwork(0, Set{Int}[], Int[], Bool[], Bool[])
end

function _pmkt_add_agent!(net::PMktNetwork)
    push!(net.adj, Set{Int}())
    push!(net.degree, 0)
    push!(net.buy_apple, false)
    push!(net.buy_samsung, false)
    net.n_agents += 1
    return net.n_agents
end

function _pmkt_add_edge!(net::PMktNetwork, i::Int, j::Int)
    if j ∉ net.adj[i]
        push!(net.adj[i], j)
        push!(net.adj[j], i)
        net.degree[i] += 1
        net.degree[j] += 1
    end
end

mutable struct PMktStats
    count_apple::Int
    count_samsung::Int
end
PMktStats() = PMktStats(0, 0)
