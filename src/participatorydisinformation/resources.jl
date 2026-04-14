mutable struct PDisinfoNetwork
    n_total::Int                    # num_people + 1 (elite)
    adj::Vector{Set{Int}}
    degree::Vector{Int}
    agent_type::Vector{Int}         # 0=regular, 1=influencer, 2=elite
    rumors::Vector{BitVector}       # BitVector of length max_rumors per agent
end

function PDisinfoNetwork()
    PDisinfoNetwork(0, Set{Int}[], Int[], Int[], BitVector[])
end

function _pdisinfo_add_agent!(net::PDisinfoNetwork, max_rumors::Int)
    push!(net.adj, Set{Int}())
    push!(net.degree, 0)
    push!(net.agent_type, 0)
    push!(net.rumors, falses(max_rumors))
    net.n_total += 1
    return net.n_total
end

function _pdisinfo_add_edge!(net::PDisinfoNetwork, i::Int, j::Int)
    if j ∉ net.adj[i]
        push!(net.adj[i], j)
        push!(net.adj[j], i)
        net.degree[i] += 1
        net.degree[j] += 1
    end
end

mutable struct PDisinfoStats
    times_heard_from_elites::Int
    times_heard_from_social::Int
    times_traded_up::Int
    times_created_rumor::Int
end
PDisinfoStats() = PDisinfoStats(0, 0, 0, 0)
