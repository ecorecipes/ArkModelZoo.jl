# --- Initialization ---

struct InitSGASystem <: System end

function initialize!(::InitSGASystem, world::World)
    params = get_resource(world, SGAParams)
    rng = get_resource(world, RNGResource).rng

    for _ in 1:params.population_size
        bits = [rand(rng, 0:1) for _ in 1:params.chromosome_length]
        fitness = sum(bits)
        new_entity!(world, (SGABits(bits, fitness),))
    end

    _sga_update_stats!(world)
    return nothing
end

# --- Go: create next generation ---

struct SGAGoSystem <: System end

function update!(::SGAGoSystem, world::World)
    params = get_resource(world, SGAParams)
    rng = get_resource(world, RNGResource).rng
    stats = get_resource(world, SGAStats)

    # Check termination: perfect solution found
    if stats.best_fitness >= params.chromosome_length
        get_resource(world, Terminate).stop = true
        return nothing
    end

    # Collect old generation
    old_eids = Entity[]
    old_bits_list = SGABits[]
    for (eids, bits_arr) in Query(world, (SGABits,))
        for i in eachindex(eids)
            push!(old_eids, eids[i])
            push!(old_bits_list, bits_arr[i])
        end
    end

    n = params.population_size
    crossover_count = floor(Int, n * params.crossover_rate / 100.0 / 2)

    new_individuals = SGABits[]

    # Crossover
    for _ in 1:crossover_count
        p1 = _sga_tournament(rng, old_bits_list, 3)
        p2 = _sga_tournament(rng, old_bits_list, 3)
        c1_bits, c2_bits = _sga_crossover(rng, old_bits_list[p1].bits, old_bits_list[p2].bits)
        push!(new_individuals, SGABits(c1_bits, 0))
        push!(new_individuals, SGABits(c2_bits, 0))
    end

    # Clone remainder
    remainder = n - crossover_count * 2
    for _ in 1:remainder
        idx = _sga_tournament(rng, old_bits_list, 3)
        push!(new_individuals, SGABits(copy(old_bits_list[idx].bits), 0))
    end

    # Remove old generation
    for eid in old_eids
        remove_entity!(world, eid)
    end

    # Create new generation with mutation
    for ind in new_individuals
        _sga_mutate!(rng, ind.bits, params.mutation_rate)
        ind.fitness = sum(ind.bits)
        new_entity!(world, (ind,))
    end

    _sga_update_stats!(world)
    return nothing
end

function _sga_tournament(rng, pop::Vector{SGABits}, k::Int)
    n = length(pop)
    best_idx = rand(rng, 1:n)
    best_fit = pop[best_idx].fitness
    for _ in 2:k
        idx = rand(rng, 1:n)
        if pop[idx].fitness > best_fit
            best_fit = pop[idx].fitness
            best_idx = idx
        end
    end
    return best_idx
end

function _sga_crossover(rng, bits1::Vector{Int}, bits2::Vector{Int})
    len = length(bits1)
    split = 1 + rand(rng, 0:len-2)
    c1 = vcat(bits1[1:split], bits2[split+1:end])
    c2 = vcat(bits2[1:split], bits1[split+1:end])
    return c1, c2
end

function _sga_mutate!(rng, bits::Vector{Int}, rate::Float64)
    for i in eachindex(bits)
        if rand(rng) * 100.0 < rate
            bits[i] = 1 - bits[i]
        end
    end
end

function _sga_update_stats!(world::World)
    stats = get_resource(world, SGAStats)
    fitnesses = Int[]
    for (_, bits_arr) in Query(world, (SGABits,))
        for b in bits_arr
            push!(fitnesses, b.fitness)
        end
    end
    if !isempty(fitnesses)
        stats.best_fitness = Float64(maximum(fitnesses))
        stats.mean_fitness = mean(fitnesses)
        stats.worst_fitness = Float64(minimum(fitnesses))
    end
    # Diversity: mean pairwise Hamming distance (sample if large)
    stats.diversity = _sga_diversity(world)
end

function _sga_diversity(world::World)
    all_bits = Vector{Int}[]
    for (_, bits_arr) in Query(world, (SGABits,))
        for b in bits_arr
            push!(all_bits, b.bits)
        end
    end
    n = length(all_bits)
    n < 2 && return 0.0
    len = length(all_bits[1])
    total_dist = 0.0
    npairs = 0
    for i in 1:n, j in i+1:n
        d = 0
        for k in 1:len
            if all_bits[i][k] != all_bits[j][k]
                d += 1
            end
        end
        total_dist += d / len
        npairs += 1
    end
    max_possible = floor(Int, n * n / 4)
    max_possible == 0 && return 0.0
    return total_dist / max_possible
end

# --- Termination ---

struct SGATerminationSystem <: System end

function update!(::SGATerminationSystem, world::World)
    params = get_resource(world, SGAParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
