struct InitPDSSystem <: System end

function initialize!(::InitPDSSystem, world::World)
    params = get_resource(world, PDSimpleParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, PDSGrid)
    stats = get_resource(world, PDSStats)
    w, h = grid.width, grid.height

    n_coop = 0
    for x in 1:w, y in 1:h
        if rand(rng) < params.init_coop_freq
            grid.strategy[x, y] = 1
            n_coop += 1
        else
            grid.strategy[x, y] = 0
        end
        grid.payoff[x, y] = 0.0
    end
    stats.n_cooperators = n_coop
    return nothing
end

# --- Play Game ---

struct PDSPlayGameSystem <: System end

function update!(::PDSPlayGameSystem, world::World)
    params = get_resource(world, PDSimpleParams)
    grid = get_resource(world, PDSGrid)
    stats = get_resource(world, PDSStats)
    w, h = grid.width, grid.height
    strategy = grid.strategy
    payoff = grid.payoff

    # Early termination check: all same strategy
    n_coop = stats.n_cooperators
    total = w * h
    if n_coop == 0 || n_coop == total
        get_resource(world, Terminate).stop = true
        return nothing
    end

    b = params.payoff_benefit
    c = params.payoff_cost

    for x in 1:w, y in 1:h
        # Count cooperating and defecting neighbors (Von Neumann, toroidal)
        n_C = 0
        n_D = 0
        for (dx, dy) in ((0, 1), (1, 0), (0, -1), (-1, 0))
            nx = mod1(x + dx, w)
            ny = mod1(y + dy, h)
            if strategy[nx, ny] == 1
                n_C += 1
            else
                n_D += 1
            end
        end

        if strategy[x, y] == 1
            payoff[x, y] = n_C * (b - c) - n_D * c
        else
            payoff[x, y] = n_C * b
        end
    end
    return nothing
end

# --- Evolve ---

struct PDSEvolveSystem <: System end

function update!(::PDSEvolveSystem, world::World)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, PDSGrid)
    stats = get_resource(world, PDSStats)
    w, h = grid.width, grid.height
    strategy = grid.strategy
    payoff = grid.payoff

    # Check if terminated (all same strategy)
    term = get_resource(world, Terminate)
    term.stop && return nothing

    # Random order iteration
    perm = randperm(rng, w * h)
    for idx in perm
        y = (idx - 1) ÷ w + 1
        x = (idx - 1) % w + 1

        my_payoff = payoff[x, y]

        # Find best neighbor (Von Neumann, toroidal)
        best_payoff = -Inf
        best_x, best_y = x, y
        for (dx, dy) in ((0, 1), (1, 0), (0, -1), (-1, 0))
            nx = mod1(x + dx, w)
            ny = mod1(y + dy, h)
            if payoff[nx, ny] > best_payoff
                best_payoff = payoff[nx, ny]
                best_x, best_y = nx, ny
            end
        end

        # Copy strategy if neighbor is better
        if best_payoff > my_payoff
            strategy[x, y] = strategy[best_x, best_y]
        end
    end

    # Update cooperator count
    n_coop = 0
    for i in eachindex(strategy)
        if strategy[i] == 1
            n_coop += 1
        end
    end
    stats.n_cooperators = n_coop

    return nothing
end

# --- Termination ---

struct PDSTerminationSystem <: System end

function update!(::PDSTerminationSystem, world::World)
    params = get_resource(world, PDSimpleParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
