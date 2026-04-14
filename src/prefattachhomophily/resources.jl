mutable struct PAHNetwork
    n::Int
    adj::Vector{Set{Int}}
    wealth::Vector{Int}
    my_prob_homophily::Vector{Int}
end
PAHNetwork() = PAHNetwork(0, Set{Int}[], Int[], Int[])

function _pah_add_node!(net::PAHNetwork, wealth::Int, prob_h::Int)
    net.n += 1
    push!(net.adj, Set{Int}())
    push!(net.wealth, wealth)
    push!(net.my_prob_homophily, prob_h)
    return net.n
end

function _pah_add_edge!(net::PAHNetwork, i::Int, j::Int)
    i == j && return
    push!(net.adj[i], j)
    push!(net.adj[j], i)
end

function _pah_num_links(net::PAHNetwork)
    s = 0
    for a in net.adj
        s += length(a)
    end
    return div(s, 2)
end

mutable struct PAHStats
    number_homophily::Int
    num_links::Int
end
PAHStats() = PAHStats(0, 0)
