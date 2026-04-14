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
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = bayesian_model(params)
    obs = BayesianObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, bayesian_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, bayesian_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
