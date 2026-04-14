# Products Market – ECS systems
# Bass-model product adoption on BA network with two competing products

struct InitPMktSystem <: System end

function _pmkt_build_ba!(net::PMktNetwork, rng, n::Int)
    # Start with 2 connected nodes
    _pmkt_add_agent!(net)
    _pmkt_add_agent!(net)
    _pmkt_add_edge!(net, 1, 2)
    # Each new node connects to 1 existing (preferential attachment, m=1)
    for _ in 3:n
        new_id = _pmkt_add_agent!(net)
        total_degree = sum(net.degree[k] for k in 1:(new_id - 1))
        if total_degree == 0
            target = rand(rng, 1:(new_id - 1))
        else
            r = rand(rng) * total_degree
            cumulative = 0.0
            target = 1
            for j in 1:(new_id - 1)
                cumulative += net.degree[j]
                if cumulative >= r
                    target = j
                    break
                end
            end
        end
        _pmkt_add_edge!(net, new_id, target)
    end
end

function initialize!(::InitPMktSystem, world::World)
    params = get_resource(world, PMktParams)
    rng    = get_resource(world, RNGResource).rng
    net    = get_resource(world, PMktNetwork)
    stats  = get_resource(world, PMktStats)

    _pmkt_build_ba!(net, rng, params.number_of_people)

    # Random seeding: pick sponsors without overlap
    indices = Random.shuffle(rng, collect(1:params.number_of_people))
    for i in 1:params.sponsor_apple
        net.buy_apple[indices[i]] = true
    end
    offset = params.sponsor_apple
    for i in 1:params.sponsor_samsung
        net.buy_samsung[indices[offset + i]] = true
    end

    stats.count_apple   = count(net.buy_apple)
    stats.count_samsung = count(net.buy_samsung)
    return nothing
end

# --- Adoption helper ---
# NetLogo random-float(N): N<0 → uniform in (N,0); N>0 → uniform in [0,N)
function _pmkt_try_adopt!(rng, net::PMktNetwork, i::Int,
                          frac::Float64, valore::Float64, is_apple::Bool)
    frac <= 0.0 && return
    prob = frac * 0.5
    rn = rand(rng) * valore          # negative when valore < 0
    if rn < prob
        if is_apple
            net.buy_apple[i] = true
        else
            net.buy_samsung[i] = true
        end
    end
end

# --- Main go procedure ---

struct PMktGoSystem <: System end

function update!(::PMktGoSystem, world::World)
    params = get_resource(world, PMktParams)
    rng    = get_resource(world, RNGResource).rng
    net    = get_resource(world, PMktNetwork)
    stats  = get_resource(world, PMktStats)

    # Termination: all bought one product
    if stats.count_apple == net.n_agents || stats.count_samsung == net.n_agents
        get_resource(world, Terminate).stop = true
        return nothing
    end

    valore_apple   = 5.0 - params.popularity_apple
    valore_samsung = 5.0 - params.popularity_samsung

    order = Random.shuffle(rng, collect(1:net.n_agents))
    for i in order
        r = rand(rng)
        if r < 0.02
            # Random adoption (2 %): coin-flip product
            if rand(rng) < 0.5
                net.buy_apple[i] = true
            else
                net.buy_samsung[i] = true
            end
            continue
        end

        # Neighbour influence (98 %)
        neighbors = net.adj[i]
        total_neighbors = length(neighbors)
        total_neighbors == 0 && continue

        apple_nbrs   = count(j -> net.buy_apple[j],   neighbors)
        samsung_nbrs = count(j -> net.buy_samsung[j],  neighbors)

        apple_frac   = apple_nbrs   / total_neighbors
        samsung_frac = samsung_nbrs / total_neighbors

        if apple_frac > samsung_frac
            _pmkt_try_adopt!(rng, net, i, apple_frac,   valore_apple,   true)
            _pmkt_try_adopt!(rng, net, i, samsung_frac,  valore_samsung, false)
        elseif samsung_frac > apple_frac
            _pmkt_try_adopt!(rng, net, i, samsung_frac,  valore_samsung, false)
            _pmkt_try_adopt!(rng, net, i, apple_frac,    valore_apple,   true)
        else
            if rand(rng) < 0.5
                _pmkt_try_adopt!(rng, net, i, apple_frac,   valore_apple,   true)
                _pmkt_try_adopt!(rng, net, i, samsung_frac,  valore_samsung, false)
            else
                _pmkt_try_adopt!(rng, net, i, samsung_frac,  valore_samsung, false)
                _pmkt_try_adopt!(rng, net, i, apple_frac,    valore_apple,   true)
            end
        end
    end

    stats.count_apple   = count(net.buy_apple)
    stats.count_samsung = count(net.buy_samsung)
    return nothing
end

# --- Tick-limit termination ---

struct PMktTerminationSystem <: System end

function update!(::PMktTerminationSystem, world::World)
    params = get_resource(world, PMktParams)
    tick   = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
