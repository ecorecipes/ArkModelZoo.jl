mutable struct SDiffNetwork
    n_agents::Int
    adopted::Vector{Bool}
    attitude::Vector{Float64}
    pers_one::Vector{Float64}     # probability (0-100) of attempting persuasion
    pers_power::Vector{Float64}   # persuasion strength
    message::Vector{Float64}      # incoming message this tick
    adj::Vector{Set{Int}}
    degree::Vector{Int}
end

function SDiffNetwork()
    SDiffNetwork(0, Bool[], Float64[], Float64[], Float64[], Float64[], Set{Int}[], Int[])
end

function _sdiff_add_agent!(net::SDiffNetwork)
    push!(net.adopted, false)
    push!(net.attitude, 0.0)
    push!(net.pers_one, 0.0)
    push!(net.pers_power, 0.0)
    push!(net.message, 0.0)
    push!(net.adj, Set{Int}())
    push!(net.degree, 0)
    net.n_agents += 1
    return net.n_agents
end

function _sdiff_add_edge!(net::SDiffNetwork, i::Int, j::Int)
    if j ∉ net.adj[i]
        push!(net.adj[i], j)
        push!(net.adj[j], i)
        net.degree[i] += 1
        net.degree[j] += 1
    end
end

mutable struct SDiffStats
    current_adopted::Int
    status_quo_counter::Int
    status_quo::Bool
end
SDiffStats() = SDiffStats(0, 0, false)
