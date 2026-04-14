# --- Helper: linear index <-> (x,y) ---
@inline function _cyber_idx(x::Int, y::Int, w::Int)
    return (y - 1) * w + x
end

@inline function _cyber_xy(idx::Int, w::Int)
    y = div(idx - 1, w) + 1
    x = mod(idx - 1, w) + 1
    return (x, y)
end

# --- Scale-free network via Barabási-Albert preferential attachment ---
function _cyber_build_scale_free!(net::CyberNetwork, n::Int, rng)
    # Start with 2 connected nodes
    push!(net.adj[1], 2)
    push!(net.adj[2], 1)
    degree = zeros(Int, n)
    degree[1] = 1
    degree[2] = 1
    total_degree = 2

    for i in 3:n
        # Connect to one existing node with probability proportional to degree
        r = rand(rng) * total_degree
        cumsum = 0.0
        target = 1
        for j in 1:(i-1)
            cumsum += degree[j]
            if cumsum >= r
                target = j
                break
            end
        end
        push!(net.adj[i], target)
        push!(net.adj[target], i)
        degree[i] += 1
        degree[target] += 1
        total_degree += 2
    end
    return degree
end

# --- Moore neighborhood (non-wrapping) ---
function _cyber_moore_neighbors(x::Int, y::Int, w::Int, h::Int)
    neighbors = Tuple{Int,Int}[]
    for dx in -1:1, dy in -1:1
        (dx == 0 && dy == 0) && continue
        nx, ny = x + dx, y + dy
        if 1 <= nx <= w && 1 <= ny <= h
            push!(neighbors, (nx, ny))
        end
    end
    return neighbors
end

# --- Systems ---

struct InitCyberSystem <: System end

function initialize!(::InitCyberSystem, world::World)
    params = get_resource(world, CyberParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, CyberGrid)
    net = get_resource(world, CyberNetwork)
    w = grid.width
    h = grid.height
    n = w * h

    # 1. Set sentiment = clamp(randn(), -1, 1)
    for i in 1:w, j in 1:h
        grid.sentiment[i, j] = clamp(randn(rng), -1.0, 1.0)
    end

    # 2. Build scale-free network
    degree = _cyber_build_scale_free!(net, n, rng)

    # 3. Top n_extremist_leaders by degree become extremist leaders
    sorted_indices = sortperm(degree; rev=true)
    leaders = sorted_indices[1:min(params.n_extremist_leaders, n)]
    for idx in leaders
        x, y = _cyber_xy(idx, w)
        grid.extremist[x, y] = true
        grid.sentiment[x, y] = 1.0
    end

    # 4. Spread extremism: neighbors (network + spatial) of leaders with sentiment >= threshold
    for idx in leaders
        lx, ly = _cyber_xy(idx, w)
        # Network neighbors
        for nidx in net.adj[idx]
            nx, ny = _cyber_xy(nidx, w)
            if grid.sentiment[nx, ny] >= params.threshold_sentiment
                grid.extremist[nx, ny] = true
                grid.sentiment[nx, ny] = 1.0
            end
        end
        # Spatial (Moore) neighbors
        for (nx, ny) in _cyber_moore_neighbors(lx, ly, w, h)
            if grid.sentiment[nx, ny] >= params.threshold_sentiment
                grid.extremist[nx, ny] = true
                grid.sentiment[nx, ny] = 1.0
            end
        end
    end

    # 5. Non-extremists get vaccinated
    for i in 1:w, j in 1:h
        if !grid.extremist[i, j]
            grid.vaccinated[i, j] = true
        end
    end

    # 6. Susceptible = not vaccinated
    for i in 1:w, j in 1:h
        grid.susceptible[i, j] = !grid.vaccinated[i, j]
    end

    # 7. Infect n_initial_infected random susceptible agents
    susceptible_cells = Tuple{Int,Int}[]
    for i in 1:w, j in 1:h
        if grid.susceptible[i, j]
            push!(susceptible_cells, (i, j))
        end
    end
    n_to_infect = min(params.n_initial_infected, length(susceptible_cells))
    if n_to_infect > 0
        shuffle!(rng, susceptible_cells)
        for k in 1:n_to_infect
            x, y = susceptible_cells[k]
            grid.infected[x, y] = true
        end
    end

    # Update stats
    _cyber_update_stats!(world)
end

function _cyber_update_stats!(world::World)
    grid = get_resource(world, CyberGrid)
    stats = get_resource(world, CyberStats)
    stats.n_infected = count(grid.infected)
    stats.n_recovered = count(grid.recovered)
    stats.n_susceptible = count(grid.susceptible .& .!grid.infected .& .!grid.recovered)
end

struct CyberSpreadSystem <: System end

function update!(::CyberSpreadSystem, world::World)
    params = get_resource(world, CyberParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, CyberGrid)
    w = grid.width
    h = grid.height

    # Spread disease: susceptible (not recovered) can get infected from Moore neighbors
    new_infected = falses(w, h)
    for x in 1:w, y in 1:h
        if grid.susceptible[x, y] && !grid.recovered[x, y] && !grid.infected[x, y]
            n_infected_neighbors = 0
            for (nx, ny) in _cyber_moore_neighbors(x, y, w, h)
                if grid.infected[nx, ny]
                    n_infected_neighbors += 1
                end
            end
            if n_infected_neighbors > 0
                prob = 1.0 - exp(-params.infection_rate * n_infected_neighbors)
                if rand(rng) <= prob
                    new_infected[x, y] = true
                end
            end
        end
    end
    # Apply new infections
    for x in 1:w, y in 1:h
        if new_infected[x, y]
            grid.infected[x, y] = true
        end
    end
end

struct CyberRecoverSystem <: System end

function update!(::CyberRecoverSystem, world::World)
    params = get_resource(world, CyberParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, CyberGrid)
    w = grid.width
    h = grid.height

    for x in 1:w, y in 1:h
        if grid.infected[x, y]
            if rand(rng) <= params.recover_rate
                grid.recovered[x, y] = true
                grid.infected[x, y] = false
                grid.susceptible[x, y] = false
            end
        end
    end
end

struct CyberStatsSystem <: System end

function update!(::CyberStatsSystem, world::World)
    _cyber_update_stats!(world)
end

struct CyberTerminationSystem <: System end

function update!(::CyberTerminationSystem, world::World)
    params = get_resource(world, CyberParams)
    tick = get_resource(world, Tick).tick
    if tick >= params.num_ticks
        get_resource(world, Terminate).stop = true
    end
end
