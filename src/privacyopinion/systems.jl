# --- Small-world graph generation (Watts–Strogatz) ---

function _prv_build_small_world!(net::PrvNetwork, rng, k::Int, p::Float64)
    n = net.n
    # Ring lattice: connect each node to k neighbors on each side
    for i in 1:n
        for j in 1:k
            nb = mod1(i + j, n)
            push!(net.adjacency[i], nb)
            push!(net.adjacency[nb], i)
        end
    end
    # Rewire edges with probability p
    for i in 1:n
        for j in 1:k
            nb = mod1(i + j, n)
            if rand(rng) < p
                # Pick random new target (not self, not already neighbor)
                attempts = 0
                while attempts < 100
                    new_nb = rand(rng, 1:n)
                    if new_nb != i && !(new_nb in net.adjacency[i])
                        delete!(net.adjacency[i], nb)
                        delete!(net.adjacency[nb], i)
                        push!(net.adjacency[i], new_nb)
                        push!(net.adjacency[new_nb], i)
                        break
                    end
                    attempts += 1
                end
            end
        end
    end
end

# --- Initialization ---

struct InitPrvSystem <: System end

function initialize!(::InitPrvSystem, world::World)
    params = get_resource(world, PrvParams)
    rng = get_resource(world, RNGResource).rng
    net = get_resource(world, PrvNetwork)
    counters = get_resource(world, PrvCounters)
    stats = get_resource(world, PrvStats)

    _prv_build_small_world!(net, rng, params.k_neighbors, params.rewire_prob)

    adopters = 0
    for i in 1:net.n
        net.attitudes[i] = rand(rng)
        net.willingness[i] = rand(rng)
        net.updated_attitudes[i] = net.attitudes[i]
        net.adopted[i] = net.attitudes[i] >= params.adoption_threshold
        if net.adopted[i]
            adopters += 1
        end
    end

    counters.hr_tick_counter = 0
    counters.pv_tick_counter = 0

    stats.adopters_total = adopters
    stats.adopter_percent = 100.0 * adopters / net.n
    return nothing
end

# --- Propagate privacy thresholds (bounded-confidence averaging) ---

struct PrvPropagateSystem <: System end

function update!(::PrvPropagateSystem, world::World)
    params = get_resource(world, PrvParams)
    net = get_resource(world, PrvNetwork)
    threshold = params.bounded_confidence_threshold

    for i in 1:net.n
        my_att = net.attitudes[i]
        delta_sum = 0.0
        eligible_count = 0
        for nb in net.adjacency[i]
            diff = net.attitudes[nb] - my_att
            if abs(diff) <= threshold
                delta_sum += diff
                eligible_count += 1
            end
        end
        if eligible_count > 0
            att_delta = delta_sum / (1 + eligible_count)
            net.updated_attitudes[i] = my_att + net.willingness[i] * att_delta
        else
            net.updated_attitudes[i] = my_att
        end
    end
    return nothing
end

# --- Block update: copy updated attitudes ---

struct PrvBlockUpdateSystem <: System end

function update!(::PrvBlockUpdateSystem, world::World)
    net = get_resource(world, PrvNetwork)
    for i in 1:net.n
        net.attitudes[i] = clamp(net.updated_attitudes[i], 0.0, 1.0)
    end
    return nothing
end

# --- Check adopters ---

struct PrvCheckAdoptersSystem <: System end

function update!(::PrvCheckAdoptersSystem, world::World)
    params = get_resource(world, PrvParams)
    net = get_resource(world, PrvNetwork)
    stats = get_resource(world, PrvStats)
    adopters = 0
    for i in 1:net.n
        net.adopted[i] = net.attitudes[i] >= params.adoption_threshold
        if net.adopted[i]
            adopters += 1
        end
    end
    stats.adopters_total = adopters
    stats.adopter_percent = 100.0 * adopters / net.n
    return nothing
end

# --- HR material distribution ---

struct PrvHRSystem <: System end

function update!(::PrvHRSystem, world::World)
    params = get_resource(world, PrvParams)
    net = get_resource(world, PrvNetwork)
    counters = get_resource(world, PrvCounters)
    rng = get_resource(world, RNGResource).rng

    counters.hr_tick_counter += 1
    if !params.enable_hr
        return nothing
    end
    if counters.hr_tick_counter < counters.hr_tick_interval
        return nothing
    end
    counters.hr_tick_counter = 0
    # Push attitudes toward 1.0 for agents within HR bounded confidence threshold
    hr_threshold = params.hr_bounded_confidence_threshold
    for i in 1:net.n
        if abs(1.0 - net.attitudes[i]) <= hr_threshold
            delta = (1.0 - net.attitudes[i])
            net.attitudes[i] = clamp(net.attitudes[i] + net.willingness[i] * delta, 0.0, 1.0)
        end
    end
    return nothing
end

# --- Privacy violation ---

struct PrvPVSystem <: System end

function update!(::PrvPVSystem, world::World)
    params = get_resource(world, PrvParams)
    net = get_resource(world, PrvNetwork)
    counters = get_resource(world, PrvCounters)
    rng = get_resource(world, RNGResource).rng

    counters.pv_tick_counter += 1
    if !params.enable_pv
        return nothing
    end
    if counters.pv_tick_counter < counters.pv_tick_interval
        return nothing
    end
    counters.pv_tick_counter = 0

    # Power-law random shock: draw PL value, push attitudes down proportionally
    # NetLogo PLRandomValue: power-law distributed magnitude of privacy incident
    u = rand(rng)
    pl_value = u^2  # power-law concentrated near 0, max 1.0

    pv_threshold = params.pv_bounded_confidence_threshold
    for i in 1:net.n
        if net.attitudes[i] <= pv_threshold
            shock = pl_value * net.willingness[i] * net.attitudes[i] * 0.15
            net.attitudes[i] = clamp(net.attitudes[i] - shock, 0.0, 1.0)
        end
    end
    return nothing
end

# --- Termination ---

struct PrvTerminationSystem <: System end

function update!(::PrvTerminationSystem, world::World)
    params = get_resource(world, PrvParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
