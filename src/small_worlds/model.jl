function sw_world(; initial_capacity::Int = 256)
    return World(SWNode; initial_capacity = initial_capacity, allow_mutable = true)
end

function sw_systems()
    return (InitSWSystem(), SWRewireSystem(), SWTerminationSystem())
end

function sw_model(params::SWParams = SWParams())
    world = sw_world()
    _add_standard_resources!(world, params)
    add_resource!(world, SWNetwork())
    add_resource!(world, SWStats())
    scheduler = Scheduler(world, sw_systems())
    initialize!(scheduler)
    return scheduler
end

struct SWObserver end

function sw_headers(::SWObserver)
    return ["ClusteringCoeff", "AvgPathLength", "NumRewired"]
end

function sw_values(::SWObserver, world::World)
    stats = get_resource(world, SWStats)
    return Float64[stats.clustering_coefficient, stats.average_path_length,
                    Float64(stats.number_rewired)]
end

function run_small_worlds(; params::SWParams = SWParams(), observe::Bool = true)
    return _run_model(sw_model, SWObserver(), sw_values; params, observe)
end
