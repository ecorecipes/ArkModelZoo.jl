mutable struct CNWNetwork
    n::Int
    adj::Vector{Set{Int}}
    infected::Vector{Bool}
end
CNWNetwork() = CNWNetwork(0, Set{Int}[], Bool[])

function _cnw_add_node!(net::CNWNetwork; infected::Bool=false)
    net.n += 1
    push!(net.adj, Set{Int}())
    push!(net.infected, infected)
    return net.n
end

function _cnw_add_edge!(net::CNWNetwork, i::Int, j::Int)
    i == j && return
    push!(net.adj[i], j)
    push!(net.adj[j], i)
end

function _cnw_num_links(net::CNWNetwork)
    s = 0
    for a in net.adj
        s += length(a)
    end
    return div(s, 2)
end

mutable struct CNWStats
    num_infected::Int
    num_links::Int
end
CNWStats() = CNWStats(0, 0)
