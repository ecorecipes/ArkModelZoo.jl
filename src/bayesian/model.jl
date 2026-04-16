function bayesian_world(; initial_capacity::Int = 128)
    return World(
        BayesianDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function bayesian_systems()
    return (
        InitBayesianSystem(),
        BayesianUpdateSystem(),
        BayesianTerminationSystem(),
    )
end

function bayesian_model(params::BayesianParams = BayesianParams())
    world = bayesian_world()
    _add_standard_resources!(world, params)
    add_resource!(world, BayesianState())
    scheduler = Scheduler(world, bayesian_systems())
    initialize!(scheduler)
    return scheduler
end

struct BayesianObserver end

function bayesian_headers(::BayesianObserver)
    return ["ProbTrue"]
end

function bayesian_values(::BayesianObserver, world::World)
    state = get_resource(world, BayesianState)
    return Float64[state.prob_true]
end

function run_bayesian(; params::BayesianParams = BayesianParams(), observe::Bool = true)
    return _run_model(bayesian_model, BayesianObserver(), bayesian_values; params, observe)
end
