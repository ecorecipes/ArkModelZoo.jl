mutable struct SGroupNetwork
    n_agents::Int
    adj::Vector{Set{Int}}
    degree::Vector{Int}
    infected::Vector{Bool}
    agent_size::Vector{Float64}
    spreading_group::Vector{Bool}
end

function SGroupNetwork()
    SGroupNetwork(0, Set{Int}[], Int[], Bool[], Float64[], Bool[])
end

function _sgroup_add_agent!(net::SGroupNetwork)
    push!(net.adj, Set{Int}())
    push!(net.degree, 0)
    push!(net.infected, false)
    push!(net.agent_size, 1.0)
    push!(net.spreading_group, false)
    net.n_agents += 1
    return net.n_agents
end

function _sgroup_add_edge!(net::SGroupNetwork, i::Int, j::Int)
    if j ∉ net.adj[i]
        push!(net.adj[i], j)
        push!(net.adj[j], i)
        net.degree[i] += 1
        net.degree[j] += 1
    end
end

mutable struct SGroupStats
    num_infected::Int           # cumulative infection counter (tracked output, matches NetLogo global)
    prev_infected_count::Int    # post-infection current count for stalling check
end
SGroupStats() = SGroupStats(0, 0)
