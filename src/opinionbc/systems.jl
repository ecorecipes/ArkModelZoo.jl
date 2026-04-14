# --- Initialization ---

struct InitOpinionBCSystem <: System end

function initialize!(::InitOpinionBCSystem, world::World)
    params = get_resource(world, OpinionBCParams)
    rng = get_resource(world, RNGResource).rng
    pop = get_resource(world, OpinionBCPopulation)
    stats = get_resource(world, OpinionBCStats)

    # Each turtle gets opinion = (random-float 2) - 1 → uniform [-1, 1)
    for i in 1:params.num_agents
        pop.opinions[i] = rand(rng) * 2.0 - 1.0
    end

    # Initial stats
    stats.mean_opinion = Statistics.mean(pop.opinions)
    stats.sd_opinion = Statistics.std(pop.opinions; corrected=true)
    return nothing
end

# --- Opinion Update ---
# NetLogo: ask one-of turtles [ pick another, if within threshold, move toward each other ]
# ONE interaction per tick

struct OpinionBCUpdateSystem <: System end

function update!(::OpinionBCUpdateSystem, world::World)
    params = get_resource(world, OpinionBCParams)
    rng = get_resource(world, RNGResource).rng
    pop = get_resource(world, OpinionBCPopulation)
    n = params.num_agents

    # Pick one random turtle
    i = rand(rng, 1:n)
    # Pick another random turtle (not self)
    j = rand(rng, 1:n-1)
    if j >= i
        j += 1
    end

    x1 = pop.opinions[i]
    x2 = pop.opinions[j]

    if abs(x1 - x2) < params.confidence_threshold
        lr = params.learning_rate
        pop.opinions[i] = x1 + lr * (x2 - x1)
        pop.opinions[j] = x2 + lr * (x1 - x2)
    end
    return nothing
end

# --- Stats ---

struct OpinionBCStatsSystem <: System end

function update!(::OpinionBCStatsSystem, world::World)
    pop = get_resource(world, OpinionBCPopulation)
    stats = get_resource(world, OpinionBCStats)
    stats.mean_opinion = Statistics.mean(pop.opinions)
    stats.sd_opinion = Statistics.std(pop.opinions; corrected=true)
    return nothing
end

# --- Termination ---

struct OpinionBCTerminationSystem <: System end

function update!(::OpinionBCTerminationSystem, world::World)
    params = get_resource(world, OpinionBCParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
