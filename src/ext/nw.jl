# Network graph algorithms (NetLogo nw extension equivalent)

# ─── Graph data structure ────────────────────────────────────────────

"""
A simple undirected graph with adjacency sets.
Nodes are 1-indexed integers.
"""
mutable struct NwGraph
    n::Int
    adj::Vector{Set{Int}}
end

NwGraph() = NwGraph(0, Set{Int}[])
NwGraph(n::Int) = NwGraph(n, [Set{Int}() for _ in 1:n])

function nw_add_node!(g::NwGraph)
    g.n += 1
    push!(g.adj, Set{Int}())
    return g.n
end

function nw_add_edge!(g::NwGraph, i::Int, j::Int)
    i == j && return
    push!(g.adj[i], j)
    push!(g.adj[j], i)
end

function nw_remove_edge!(g::NwGraph, i::Int, j::Int)
    delete!(g.adj[i], j)
    delete!(g.adj[j], i)
end

nw_has_edge(g::NwGraph, i::Int, j::Int) = j in g.adj[i]
nw_degree(g::NwGraph, i::Int) = length(g.adj[i])
nw_neighbors(g::NwGraph, i::Int) = g.adj[i]

# ─── Graph generators ────────────────────────────────────────────────

"""
    nw_generate_preferential_attachment(rng, n, m; gamma=1.0) -> NwGraph

Barabási-Albert preferential attachment. Start with m+1 fully connected nodes,
add remaining nodes each connecting to m existing nodes with probability
proportional to degree^gamma.
"""
function nw_generate_preferential_attachment(rng::AbstractRNG, n::Int, m::Int; gamma::Float64=1.0)
    g = NwGraph(n)
    init = min(m + 1, n)
    for i in 1:init, j in (i+1):init
        nw_add_edge!(g, i, j)
    end
    for i in (init+1):n
        degrees = Float64[max(nw_degree(g, k), 1)^gamma for k in 1:(i-1)]
        targets = _weighted_sample_without_replacement(rng, min(m, i-1), degrees)
        for t in targets
            nw_add_edge!(g, i, t)
        end
    end
    return g
end

"""
    nw_generate_random(rng, n, p) -> NwGraph

Erdős-Rényi random graph. Each pair connected with probability p.
"""
function nw_generate_random(rng::AbstractRNG, n::Int, p::Float64)
    g = NwGraph(n)
    for i in 1:n, j in (i+1):n
        if rand(rng) < p
            nw_add_edge!(g, i, j)
        end
    end
    return g
end

"""
    nw_generate_watts_strogatz(rng, n, k, p) -> NwGraph

Watts-Strogatz small-world. Ring lattice with k neighbors, rewire with probability p.
"""
function nw_generate_watts_strogatz(rng::AbstractRNG, n::Int, k::Int, p::Float64)
    g = NwGraph(n)
    half_k = div(k, 2)
    # Build ring lattice
    for i in 1:n, d in 1:half_k
        j = mod1(i + d, n)
        nw_add_edge!(g, i, j)
    end
    # Rewire
    for i in 1:n, d in 1:half_k
        j = mod1(i + d, n)
        if rand(rng) < p
            nw_remove_edge!(g, i, j)
            new_j = rand(rng, 1:n)
            while new_j == i || nw_has_edge(g, i, new_j)
                new_j = rand(rng, 1:n)
            end
            nw_add_edge!(g, i, new_j)
        end
    end
    return g
end

"""
    nw_generate_ring(n) -> NwGraph

Simple ring (cycle) graph.
"""
function nw_generate_ring(n::Int)
    g = NwGraph(n)
    for i in 1:(n-1)
        nw_add_edge!(g, i, i + 1)
    end
    nw_add_edge!(g, n, 1)
    return g
end

"""
    nw_generate_lattice2d(rows, cols; wrap=false) -> NwGraph

2D grid lattice. Node (r,c) has index (r-1)*cols + c.
"""
function nw_generate_lattice2d(rows::Int, cols::Int; wrap::Bool=false)
    n = rows * cols
    g = NwGraph(n)
    idx(r, c) = (r - 1) * cols + c
    for r in 1:rows, c in 1:cols
        i = idx(r, c)
        if c < cols
            nw_add_edge!(g, i, idx(r, c + 1))
        elseif wrap
            nw_add_edge!(g, i, idx(r, 1))
        end
        if r < rows
            nw_add_edge!(g, i, idx(r + 1, c))
        elseif wrap
            nw_add_edge!(g, i, idx(1, c))
        end
    end
    return g
end

# ─── Path algorithms ──────────────────────────────────────────────────

"""
    nw_bfs_distances(g, source) -> Vector{Int}

BFS shortest distances from source. -1 means unreachable.
"""
function nw_bfs_distances(g::NwGraph, source::Int)
    dist = fill(-1, g.n)
    dist[source] = 0
    queue = [source]
    head = 1
    while head <= length(queue)
        u = queue[head]; head += 1
        for v in g.adj[u]
            if dist[v] == -1
                dist[v] = dist[u] + 1
                push!(queue, v)
            end
        end
    end
    return dist
end

"""
    nw_mean_path_length(g) -> Float64

Average shortest path length over all reachable pairs.
"""
function nw_mean_path_length(g::NwGraph)
    total = 0.0; count = 0
    for i in 1:g.n
        d = nw_bfs_distances(g, i)
        for j in (i+1):g.n
            if d[j] > 0
                total += d[j]; count += 1
            end
        end
    end
    return count > 0 ? total / count : 0.0
end

# ─── Centrality metrics ──────────────────────────────────────────────

"""
    nw_betweenness_centrality(g) -> Vector{Float64}

Brandes algorithm for betweenness centrality (normalized).
"""
function nw_betweenness_centrality(g::NwGraph)
    cb = zeros(g.n)
    for s in 1:g.n
        S = Int[]
        P = [Int[] for _ in 1:g.n]
        sigma = zeros(Int, g.n); sigma[s] = 1
        d = fill(-1, g.n); d[s] = 0
        queue = [s]; head = 1
        while head <= length(queue)
            v = queue[head]; head += 1
            push!(S, v)
            for w in g.adj[v]
                if d[w] < 0
                    d[w] = d[v] + 1
                    push!(queue, w)
                end
                if d[w] == d[v] + 1
                    sigma[w] += sigma[v]
                    push!(P[w], v)
                end
            end
        end
        delta = zeros(g.n)
        while !isempty(S)
            w = pop!(S)
            for v in P[w]
                delta[v] += (sigma[v] / sigma[w]) * (1.0 + delta[w])
            end
            if w != s
                cb[w] += delta[w]
            end
        end
    end
    # Normalize
    n = g.n
    if n > 2
        norm = 1.0 / ((n - 1) * (n - 2))
        cb .*= norm
    end
    return cb
end

"""
    nw_eigenvector_centrality(g; max_iter=100, tol=1e-6) -> Vector{Float64}

Power iteration for eigenvector centrality.
"""
function nw_eigenvector_centrality(g::NwGraph; max_iter::Int=100, tol::Float64=1e-6)
    x = ones(g.n) / g.n
    for _ in 1:max_iter
        x_new = zeros(g.n)
        for i in 1:g.n
            for j in g.adj[i]
                x_new[i] += x[j]
            end
        end
        norm = sqrt(sum(x_new .^ 2))
        norm > 0 && (x_new ./= norm)
        if maximum(abs.(x_new - x)) < tol
            return x_new
        end
        x = x_new
    end
    return x
end

"""
    nw_page_rank(g; damping=0.85, max_iter=100, tol=1e-6) -> Vector{Float64}

PageRank centrality.
"""
function nw_page_rank(g::NwGraph; damping::Float64=0.85, max_iter::Int=100, tol::Float64=1e-6)
    n = g.n
    pr = fill(1.0 / n, n)
    for _ in 1:max_iter
        pr_new = fill((1.0 - damping) / n, n)
        for i in 1:n
            deg = nw_degree(g, i)
            if deg > 0
                share = damping * pr[i] / deg
                for j in g.adj[i]
                    pr_new[j] += share
                end
            end
        end
        if maximum(abs.(pr_new - pr)) < tol
            return pr_new
        end
        pr = pr_new
    end
    return pr
end

"""
    nw_closeness_centrality(g) -> Vector{Float64}

Closeness centrality: 1 / (mean distance to reachable nodes).
"""
function nw_closeness_centrality(g::NwGraph)
    cc = zeros(g.n)
    for i in 1:g.n
        d = nw_bfs_distances(g, i)
        reachable = [d[j] for j in 1:g.n if d[j] > 0]
        if !isempty(reachable)
            cc[i] = length(reachable) / sum(reachable)
        end
    end
    return cc
end

"""
    nw_clustering_coefficient(g, i) -> Float64

Local clustering coefficient for node i.
"""
function nw_clustering_coefficient(g::NwGraph, i::Int)
    neighbors = collect(g.adj[i])
    k = length(neighbors)
    k < 2 && return 0.0
    triangles = 0
    for a in 1:k, b in (a+1):k
        if nw_has_edge(g, neighbors[a], neighbors[b])
            triangles += 1
        end
    end
    return 2.0 * triangles / (k * (k - 1))
end

"""
    nw_mean_clustering_coefficient(g) -> Float64
"""
function nw_mean_clustering_coefficient(g::NwGraph)
    total = sum(nw_clustering_coefficient(g, i) for i in 1:g.n)
    return total / g.n
end

# ─── Community detection ──────────────────────────────────────────────

"""
    nw_connected_components(g) -> Vector{Vector{Int}}

Find all connected components via BFS.
"""
function nw_connected_components(g::NwGraph)
    visited = falses(g.n)
    components = Vector{Vector{Int}}()
    for i in 1:g.n
        visited[i] && continue
        comp = Int[]
        queue = [i]; visited[i] = true
        head = 1
        while head <= length(queue)
            u = queue[head]; head += 1
            push!(comp, u)
            for v in g.adj[u]
                if !visited[v]
                    visited[v] = true
                    push!(queue, v)
                end
            end
        end
        push!(components, comp)
    end
    return components
end

"""
    nw_louvain_communities(g; max_iter=20) -> Vector{Vector{Int}}

Louvain community detection (greedy modularity optimization).
"""
function nw_louvain_communities(g::NwGraph; max_iter::Int=20)
    n = g.n
    m2 = sum(nw_degree(g, i) for i in 1:n)  # 2 * num_edges
    m2 == 0 && return [[i] for i in 1:n]
    comm = collect(1:n)
    # Degree of each node
    deg = [nw_degree(g, i) for i in 1:n]
    # Sum of degrees in each community
    sigma_tot = Dict{Int, Int}()
    for i in 1:n; sigma_tot[i] = deg[i]; end
    for _ in 1:max_iter
        changed = false
        for i in 1:n
            ci = comm[i]
            # Edges from i to each neighbor community
            neighbor_comm_edges = Dict{Int, Int}()
            for j in g.adj[i]
                cj = comm[j]
                neighbor_comm_edges[cj] = get(neighbor_comm_edges, cj, 0) + 1
            end
            ki = deg[i]
            # Remove i from its community
            sigma_tot[ci] -= ki
            ki_in = get(neighbor_comm_edges, ci, 0)
            best_comm = ci
            best_gain = 0.0
            for (c, ki_c) in neighbor_comm_edges
                gain = (ki_c - sigma_tot[c] * ki / m2)
                if gain > best_gain
                    best_gain = gain
                    best_comm = c
                end
            end
            # Also check staying in original community
            stay_gain = (ki_in - (sigma_tot[ci]) * ki / m2)
            if stay_gain >= best_gain
                best_comm = ci
            end
            sigma_tot[best_comm] = get(sigma_tot, best_comm, 0) + ki
            if best_comm != ci
                comm[i] = best_comm
                changed = true
            else
                sigma_tot[ci] += ki
            end
        end
        !changed && break
    end
    # Group by community label
    groups = Dict{Int, Vector{Int}}()
    for i in 1:n
        c = comm[i]
        if !haskey(groups, c)
            groups[c] = Int[]
        end
        push!(groups[c], i)
    end
    return collect(values(groups))
end

"""
    nw_label_propagation(g, rng; max_iter=20) -> Vector{Int}

Label propagation community detection. Returns community label per node.
"""
function nw_label_propagation(g::NwGraph, rng::AbstractRNG; max_iter::Int=20)
    labels = collect(1:g.n)
    for _ in 1:max_iter
        changed = false
        order = randperm(rng, g.n)
        for i in order
            isempty(g.adj[i]) && continue
            counts = Dict{Int, Int}()
            for j in g.adj[i]
                counts[labels[j]] = get(counts, labels[j], 0) + 1
            end
            max_count = maximum(values(counts))
            candidates = [l for (l, c) in counts if c == max_count]
            new_label = candidates[rand(rng, 1:length(candidates))]
            if new_label != labels[i]
                labels[i] = new_label
                changed = true
            end
        end
        !changed && break
    end
    return labels
end

"""
    nw_modularity(g, communities) -> Float64

Newman-Girvan modularity Q.
"""
function nw_modularity(g::NwGraph, communities::Vector{Vector{Int}})
    m2 = sum(nw_degree(g, i) for i in 1:g.n)
    m2 == 0 && return 0.0
    node_comm = zeros(Int, g.n)
    for (ci, comm) in enumerate(communities)
        for v in comm
            node_comm[v] = ci
        end
    end
    Q = 0.0
    for i in 1:g.n
        for j in g.adj[i]
            if node_comm[i] == node_comm[j]
                Q += 1.0 - nw_degree(g, i) * nw_degree(g, j) / m2
            end
        end
    end
    return Q / m2
end

# ─── Cliques ──────────────────────────────────────────────────────────

"""
    nw_maximal_cliques(g) -> Vector{Vector{Int}}

Bron-Kerbosch algorithm for all maximal cliques.
"""
function nw_maximal_cliques(g::NwGraph)
    cliques = Vector{Vector{Int}}()
    _bron_kerbosch!(g, Int[], collect(1:g.n), Int[], cliques)
    return cliques
end

function _bron_kerbosch!(g::NwGraph, R::Vector{Int}, P::Vector{Int}, X::Vector{Int}, cliques::Vector{Vector{Int}})
    if isempty(P) && isempty(X)
        push!(cliques, copy(R))
        return
    end
    # Pivot: choose vertex from P ∪ X with most connections to P
    pivot_candidates = vcat(P, X)
    isempty(pivot_candidates) && return
    u = pivot_candidates[argmax([length(intersect(g.adj[v], Set(P))) for v in pivot_candidates])]
    candidates = setdiff(P, g.adj[u])
    for v in candidates
        new_R = vcat(R, v)
        new_P = filter(w -> w in g.adj[v], P)
        new_X = filter(w -> w in g.adj[v], X)
        _bron_kerbosch!(g, new_R, new_P, new_X, cliques)
        P = filter(!=(v), P)
        push!(X, v)
    end
end

# ─── Helpers ──────────────────────────────────────────────────────────

function _weighted_sample_without_replacement(rng::AbstractRNG, n::Int, weights::Vector{Float64})
    result = Int[]
    ws = copy(weights)
    for _ in 1:n
        total = sum(ws)
        total <= 0 && break
        r = rand(rng) * total
        cumul = 0.0
        idx = length(ws)
        for k in 1:length(ws)
            ws[k] <= 0 && continue
            cumul += ws[k]
            if cumul >= r
                idx = k
                break
            end
        end
        push!(result, idx)
        ws[idx] = 0.0
    end
    return result
end
