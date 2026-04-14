mutable struct PDisNetwork
    n_total::Int
    adj::Vector{Set{Int}}
    agent_type::Vector{Int}         # 0=regular, 1=influencer, 2=elite
    rumors::Vector{BitVector}
end

function PDisNetwork()
    PDisNetwork(0, Set{Int}[], Int[], BitVector[])
end

function _pdis_add_agent!(net::PDisNetwork, max_rumors::Int)
    push!(net.adj, Set{Int}())
    push!(net.agent_type, 0)
    push!(net.rumors, falses(max_rumors))
    net.n_total += 1
    return net.n_total
end

function _pdis_add_edge!(net::PDisNetwork, i::Int, j::Int)
    if j ∉ net.adj[i]
        push!(net.adj[i], j)
        push!(net.adj[j], i)
    end
end

mutable struct PDisStats
    times_heard_from_elites::Int
    times_heard_from_social::Int
    times_traded_up::Int
    times_created_rumor::Int
end
PDisStats() = PDisStats(0, 0, 0, 0)
