mutable struct FNewsNetwork
    n_agents::Int
    aware::Vector{Bool}
    seed_agent::Vector{Bool}
    tick_become_aware::Vector{Int}
    adj::Vector{Set{Int}}
end

function FNewsNetwork()
    FNewsNetwork(0, Bool[], Bool[], Int[], Set{Int}[])
end

function _fnews_add_agent!(net::FNewsNetwork)
    push!(net.aware, false)
    push!(net.seed_agent, false)
    push!(net.tick_become_aware, 0)
    push!(net.adj, Set{Int}())
    net.n_agents += 1
    return net.n_agents
end

function _fnews_add_edge!(net::FNewsNetwork, i::Int, j::Int)
    if j ∉ net.adj[i]
        push!(net.adj[i], j)
        push!(net.adj[j], i)
    end
end

mutable struct FNewsStats
    pct_aware::Float64
    pct_unaware::Float64
end
FNewsStats() = FNewsStats(0.0, 0.0)
