# --- Initialization ---

struct InitBayesianSystem <: System end

function initialize!(::InitBayesianSystem, world::World)
    params = get_resource(world, BayesianParams)
    state = get_resource(world, BayesianState)
    state.prob_true = params.initial_prior
    return nothing
end

# --- Bayesian Update ---

struct BayesianUpdateSystem <: System end

function update!(::BayesianUpdateSystem, world::World)
    params = get_resource(world, BayesianParams)
    rng = get_resource(world, RNGResource).rng
    state = get_resource(world, BayesianState)

    p = state.prob_true
    fpr = params.false_positive_rate
    pwr = params.power

    # Determine if we observe a positive result this tick
    if params.true_hypothesis
        positive = rand(rng) < pwr
    else
        positive = rand(rng) < fpr
    end

    if positive
        state.prob_true = (pwr * p) / (pwr * p + fpr * (1 - p))
    else
        state.prob_true = ((1 - pwr) * p) / ((1 - pwr) * p + (1 - fpr) * (1 - p))
    end

    return nothing
end

# --- Termination ---

struct BayesianTerminationSystem <: System end

function update!(::BayesianTerminationSystem, world::World)
    params = get_resource(world, BayesianParams)
    tick = get_resource(world, Tick)
    if tick.tick + 1 >= params.max_ticks
        get_resource(world, Terminate).stop = true
    end
    return nothing
end
