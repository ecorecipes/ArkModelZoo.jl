# --- Initialization ---

struct InitIsingSystem <: System end

function initialize!(::InitIsingSystem, world::World)
    params = get_resource(world, IsingParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, IsingGrid)
    stats = get_resource(world, IsingStats)

    for x in 1:grid.width, y in 1:grid.height
        if rand(rng, 0:99) < params.probability_of_spin_up
            grid.spins[x, y] = 1
        else
            grid.spins[x, y] = -1
        end
    end

    stats.sum_of_spins = sum(grid.spins)
    return nothing
end

# --- Metropolis Update ---
# NetLogo: repeat 1000 [ ask one-of patches [ update-spin ] ]
# Each iteration picks a random patch and applies the Metropolis criterion.

struct IsingUpdateSystem <: System end

function update!(::IsingUpdateSystem, world::World)
    params = get_resource(world, IsingParams)
    rng = get_resource(world, RNGResource).rng
    grid = get_resource(world, IsingGrid)
    stats = get_resource(world, IsingStats)
    w, h = grid.width, grid.height
    spins = grid.spins
    temp = params.temperature

    for _ in 1:params.updates_per_tick
        x = rand(rng, 1:w)
        y = rand(rng, 1:h)

        # Sum of Von Neumann (neighbors4) spins with toroidal wrapping
        neighbor_sum = spins[mod1(x - 1, w), y] +
                       spins[mod1(x + 1, w), y] +
                       spins[x, mod1(y - 1, h)] +
                       spins[x, mod1(y + 1, h)]

        Ediff = 2 * spins[x, y] * neighbor_sum

        if Ediff <= 0 || (temp > 0 && rand(rng) < exp(-Ediff / temp))
            spins[x, y] = -spins[x, y]
            stats.sum_of_spins += 2 * spins[x, y]
        end
    end
    return nothing
end

# --- Termination ---

struct IsingTerminationSystem <: System end

function update!(::IsingTerminationSystem, world::World)
    params = get_resource(world, IsingParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
