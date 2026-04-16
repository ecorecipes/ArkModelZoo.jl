function competitionlearning_world(; initial_capacity::Int = 128)
    return World(CLDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function competitionlearning_systems()
    return (
        InitCLSystem(),
        CLGoSystem(),
        CLTerminationSystem(),
    )
end

function competitionlearning_model(params::CLParams = CLParams())
    world = competitionlearning_world()
    _add_standard_resources!(world, params)
    add_resource!(world, CLState())
    add_resource!(world, CLStats())
    scheduler = Scheduler(world, competitionlearning_systems())
    initialize!(scheduler)
    return scheduler
end

struct CLObserver end

function competitionlearning_headers(::CLObserver)
    return ["mean_strategy", "min_strategy"]
end

function competitionlearning_values(::CLObserver, world::World)
    stats = get_resource(world, CLStats)
    return Float64[stats.mean_strategy, stats.min_strategy]
end

function run_competitionlearning(; params::CLParams = CLParams(), observe::Bool = true)
    return _run_model(competitionlearning_model, CLObserver(), competitionlearning_values; params, observe)
end
