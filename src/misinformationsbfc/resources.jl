mutable struct MisSBFCNetwork
    n_agents::Int
    adj::Vector{Set{Int}}
    state::Vector{Char}  # 'S', 'B', or 'F'
end

function MisSBFCNetwork()
    MisSBFCNetwork(0, Set{Int}[], Char[])
end

function _msb_add_agent!(net::MisSBFCNetwork, state::Char = 'S')
    push!(net.adj, Set{Int}())
    push!(net.state, state)
    net.n_agents += 1
    return net.n_agents
end

function _msb_add_edge!(net::MisSBFCNetwork, i::Int, j::Int)
    if j ∉ net.adj[i]
        push!(net.adj[i], j)
        push!(net.adj[j], i)
    end
end

mutable struct MisSBFCStats
    num_believers::Int
    num_factcheckers::Int
    num_susceptibles::Int
end
MisSBFCStats() = MisSBFCStats(0, 0, 0)
