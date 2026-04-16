function sga_world(; initial_capacity::Int = 256)
    return World(SGABits; initial_capacity = initial_capacity, allow_mutable = true)
end

function sga_systems()
    return (
        InitSGASystem(),
        SGAGoSystem(),
        SGATerminationSystem(),
    )
end

function sga_model(params::SGAParams = SGAParams())
    world = sga_world()
    _add_standard_resources!(world, params)
    add_resource!(world, SGAStats())
    scheduler = Scheduler(world, sga_systems())
    initialize!(scheduler)
    return scheduler
end

struct SGAObserver end

function sga_headers(::SGAObserver)
    return ["BestFitness", "MeanFitness", "Diversity"]
end

function sga_values(::SGAObserver, world::World)
    stats = get_resource(world, SGAStats)
    return Float64[stats.best_fitness, stats.mean_fitness, stats.diversity]
end

function run_simple_genetic_algorithm(; params::SGAParams = SGAParams(), observe::Bool = true)
    return _run_model(sga_model, SGAObserver(), sga_values; params, observe)
end
