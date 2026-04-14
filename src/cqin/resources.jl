# Node state constants
const CQIN_SUSCEPTIBLE = 0
const CQIN_UPDATED = 1
const CQIN_AGREED = 2
const CQIN_IMPLEMENTED = 3
const CQIN_REVIEWED = 4
const CQIN_ADJUSTED = 5
const CQIN_RESISTANT = 6

mutable struct CQINNetwork
    n_nodes::Int
    states::Vector{Int}          # node state (0-6)
    schema_check_timer::Vector{Int}
    adj::Vector{Set{Int}}        # adjacency list
    degree::Vector{Int}          # cached degree per node
    iteration_count::Int
    signal::Float64
end

function CQINNetwork()
    CQINNetwork(0, Int[], Int[], Set{Int}[], Int[], 0, 0.0)
end

function _cqin_add_node!(net::CQINNetwork, state::Int)
    push!(net.states, state)
    push!(net.schema_check_timer, 0)
    push!(net.adj, Set{Int}())
    push!(net.degree, 0)
    net.n_nodes += 1
    return net.n_nodes
end

function _cqin_add_edge!(net::CQINNetwork, i::Int, j::Int)
    if i != j && j ∉ net.adj[i]
        push!(net.adj[i], j)
        push!(net.adj[j], i)
        net.degree[i] += 1
        net.degree[j] += 1
    end
end

mutable struct CQINStats
    num_updated::Int
    num_resistant::Int
    num_adjusted::Int
end
CQINStats() = CQINStats(0, 0, 0)

function _cqin_update_counts!(net::CQINNetwork, stats::CQINStats)
    stats.num_updated = count(==(CQIN_UPDATED), net.states)
    stats.num_resistant = count(==(CQIN_RESISTANT), net.states)
    stats.num_adjusted = count(==(CQIN_ADJUSTED), net.states)
end
