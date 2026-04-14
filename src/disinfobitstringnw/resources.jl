mutable struct DisBitNetwork
    n_total::Int                    # num_people + 1 (elite)
    adj::Vector{Set{Int}}
    agent_type::Vector{Int}         # 0=regular, 1=influencer, 2=elite
    rumors::Vector{BitVector}       # BitVector of length max_rumors per agent
    patch_vote::Matrix{Int}         # patch voting grid for irregular/block variant
end

function DisBitNetwork()
    DisBitNetwork(0, Set{Int}[], Int[], BitVector[], zeros(Int, 0, 0))
end

function _disbit_add_agent!(net::DisBitNetwork, max_rumors::Int)
    push!(net.adj, Set{Int}())
    push!(net.agent_type, 0)
    push!(net.rumors, falses(max_rumors))
    net.n_total += 1
    return net.n_total
end

function _disbit_add_edge!(net::DisBitNetwork, i::Int, j::Int)
    if j ∉ net.adj[i]
        push!(net.adj[i], j)
        push!(net.adj[j], i)
    end
end

mutable struct DisBitStats
    times_heard_from_elites::Int
    times_heard_from_social::Int
    times_traded_up::Int
    times_created_rumor::Int
end
DisBitStats() = DisBitStats(0, 0, 0, 0)
