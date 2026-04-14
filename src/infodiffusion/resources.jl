mutable struct InfoDiffNetwork
    n_agents::Int
    states::Vector{Int}   # 0=S, 1=B, 2=F
    adj::Vector{Set{Int}}
    degree::Vector{Int}
end

function InfoDiffNetwork()
    InfoDiffNetwork(0, Int[], Set{Int}[], Int[])
end

function _infodiff_add_agent!(net::InfoDiffNetwork, state::Int)
    push!(net.states, state)
    push!(net.adj, Set{Int}())
    push!(net.degree, 0)
    net.n_agents += 1
    return net.n_agents
end

function _infodiff_add_edge!(net::InfoDiffNetwork, i::Int, j::Int)
    if j ∉ net.adj[i]
        push!(net.adj[i], j)
        push!(net.adj[j], i)
        net.degree[i] += 1
        net.degree[j] += 1
    end
end

mutable struct InfoDiffStats
    num_believers::Int
    num_factcheckers::Int
    num_susceptibles::Int
end
InfoDiffStats() = InfoDiffStats(0, 0, 0)
