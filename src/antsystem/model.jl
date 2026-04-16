function antsystem_world(; initial_capacity::Int = 128)
    return World(TSPDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function antsystem_systems()
    return (
        InitTSPSystem(),
        TSPAntTourSystem(),
        TSPPheromoneSystem(),
        TSPTerminationSystem(),
    )
end

function antsystem_model(params::AntSystemParams = AntSystemParams())
    world = antsystem_world()
    _add_standard_resources!(world, params)
    add_resource!(world, TSPGraph(params.num_nodes))
    add_resource!(world, TSPState())
    add_resource!(world, TSPStats())
    scheduler = Scheduler(world, antsystem_systems())
    initialize!(scheduler)
    return scheduler
end

struct AntSystemObserver end

function antsystem_headers(::AntSystemObserver)
    return ["BestTourCost"]
end

function antsystem_values(::AntSystemObserver, world::World)
    stats = get_resource(world, TSPStats)
    return Float64[stats.best_tour_cost]
end

function run_antsystem(; params::AntSystemParams = AntSystemParams(), observe::Bool = true)
    return _run_model(antsystem_model, AntSystemObserver(), antsystem_values; params, observe)
end
