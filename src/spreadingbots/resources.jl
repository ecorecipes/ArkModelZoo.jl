mutable struct SBotNetwork
    n_agents::Int
    adj::Vector{Set{Int}}
    infected::Vector{Bool}
    agent_size::Vector{Float64}
    is_bot::Vector{Bool}
    degrees_bag::Vector{Int}  # degree list for preferential attachment
end

function SBotNetwork()
    SBotNetwork(0, Set{Int}[], Bool[], Float64[], Bool[], Int[])
end

function _sbot_add_agent!(net::SBotNetwork)
    push!(net.adj, Set{Int}())
    push!(net.infected, false)
    push!(net.agent_size, 0.5)
    push!(net.is_bot, false)
    net.n_agents += 1
    return net.n_agents
end

function _sbot_add_edge!(net::SBotNetwork, i::Int, j::Int)
    if i != j && j ∉ net.adj[i]
        push!(net.adj[i], j)
        push!(net.adj[j], i)
        push!(net.degrees_bag, i)
        push!(net.degrees_bag, j)
    end
end

mutable struct SBotStats
    num_infected::Int
    previous_num_infected::Int
end
SBotStats() = SBotStats(0, 0)
