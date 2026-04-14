# Von Neumann (4-neighbor) offsets: N, S, E, W
const ALT_VON_NEUMANN = ((0, -1), (0, 1), (1, 0), (-1, 0))

# --- Initialization ---

struct InitALTSystem <: System end

function initialize!(::InitALTSystem, world::World)
    params = get_resource(world, ALTParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, ALTGrid)

    for x in 1:grid.width, y in 1:grid.height
        ptype_val = rand(rng)
        if ptype_val < params.altruistic_probability
            grid.ptype[x, y] = ALT_ALTRUIST
            grid.benefit_out[x, y] = 1.0
        elseif ptype_val < params.altruistic_probability + params.selfish_probability
            grid.ptype[x, y] = ALT_SELFISH
            grid.benefit_out[x, y] = 0.0
        else
            grid.ptype[x, y] = ALT_HARSH
            grid.benefit_out[x, y] = 0.0
        end
    end

    _alt_update_stats!(grid, get_resource(world, ALTStats))
    return nothing
end

# --- Main Go System ---

struct ALTGoSystem <: System end

function update!(::ALTGoSystem, world::World)
    params = get_resource(world, ALTParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, ALTGrid)
    stats = get_resource(world, ALTStats)
    w, h = grid.width, grid.height

    # Early termination: if no altruists and no selfish patches remain, stop
    if stats.num_altruists == 0 && stats.num_selfish == 0
        get_resource(world, Terminate).stop = true
        return nothing
    end

    # Phase 1: compute altruism-benefit for each patch
    # benefit = benefit_from_altruism * (benefit_out + sum of 4 neighbors' benefit_out) / 5
    @inbounds for x in 1:w, y in 1:h
        s = grid.benefit_out[x, y]
        for (dx, dy) in ALT_VON_NEUMANN
            nx = mod1(x + dx, w)
            ny = mod1(y + dy, h)
            s += grid.benefit_out[nx, ny]
        end
        grid.altruism_benefit[x, y] = params.benefit_from_altruism * s / 5.0
    end

    # Phase 2: compute fitness for each patch
    @inbounds for x in 1:w, y in 1:h
        pt = grid.ptype[x, y]
        ab = grid.altruism_benefit[x, y]
        if pt == ALT_SELFISH
            grid.fitness[x, y] = 1.0 + ab
        elseif pt == ALT_ALTRUIST
            grid.fitness[x, y] = (1.0 - params.cost_of_altruism) + ab
        else  # ALT_HARSH
            grid.fitness[x, y] = params.harshness
        end
    end

    # Phase 3: lottery (record-neighbor-fitness, find-lottery-weights, next-generation)
    _alt_lottery!(rng, grid, params)

    _alt_update_stats!(grid, stats)
    return nothing
end

# --- Lottery ---

function _alt_lottery!(rng, grid::ALTGrid, params::ALTParams)
    w, h = grid.width, grid.height

    # Scratch buffers for weights (reuse grid fields after lottery computation)
    alt_w = grid.alt_fitness
    self_w = grid.self_fitness
    harsh_w = grid.harsh_fitness

    # Record neighbor fitness: sum fitness by type from self + 4 cardinal neighbors
    @inbounds for x in 1:w, y in 1:h
        af = 0.0; sf = 0.0; hf = 0.0
        # Self
        pt = grid.ptype[x, y]
        f = grid.fitness[x, y]
        if pt == ALT_ALTRUIST
            af += f
        elseif pt == ALT_SELFISH
            sf += f
        else
            hf += f
        end
        # 4 cardinal neighbors
        for (dx, dy) in ALT_VON_NEUMANN
            nx = mod1(x + dx, w)
            ny = mod1(y + dy, h)
            npt = grid.ptype[nx, ny]
            nf = grid.fitness[nx, ny]
            if npt == ALT_ALTRUIST
                af += nf
            elseif npt == ALT_SELFISH
                sf += nf
            else
                hf += nf
            end
        end
        alt_w[x, y] = af
        self_w[x, y] = sf
        harsh_w[x, y] = hf
    end

    # Find lottery weights: normalize
    @inbounds for x in 1:w, y in 1:h
        fitness_sum = alt_w[x, y] + self_w[x, y] + harsh_w[x, y] + params.disease
        if fitness_sum > 0.0
            alt_w[x, y] /= fitness_sum
            self_w[x, y] /= fitness_sum
            harsh_w[x, y] /= fitness_sum
        else
            alt_w[x, y] = 0.0
            self_w[x, y] = 0.0
            harsh_w[x, y] = 0.0
        end
    end

    # Next generation: probabilistic selection per patch
    @inbounds for x in 1:w, y in 1:h
        breed_chance = rand(rng)
        if breed_chance < alt_w[x, y]
            grid.ptype[x, y] = ALT_ALTRUIST
            grid.benefit_out[x, y] = 1.0
        elseif breed_chance < alt_w[x, y] + self_w[x, y]
            grid.ptype[x, y] = ALT_SELFISH
            grid.benefit_out[x, y] = 0.0
        else
            grid.ptype[x, y] = ALT_HARSH
            grid.benefit_out[x, y] = 0.0
        end
    end
end

# --- Termination ---

struct ALTTerminationSystem <: System end

function update!(::ALTTerminationSystem, world::World)
    params = get_resource(world, ALTParams)
    tick = get_resource(world, Tick)
    stats = get_resource(world, ALTStats)

    if tick.tick + 1 >= params.max_ticks || (stats.num_altruists == 0 && stats.num_selfish == 0)
        get_resource(world, Terminate).stop = true
    end
    return nothing
end

# --- Helper ---

function _alt_update_stats!(grid::ALTGrid, stats::ALTStats)
    na = 0; ns = 0; nh = 0
    @inbounds for x in 1:grid.width, y in 1:grid.height
        pt = grid.ptype[x, y]
        if pt == ALT_ALTRUIST
            na += 1
        elseif pt == ALT_SELFISH
            ns += 1
        else
            nh += 1
        end
    end
    stats.num_altruists = na
    stats.num_selfish = ns
    stats.num_harsh = nh
    return nothing
end
