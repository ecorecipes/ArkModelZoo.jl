function firebenchmark_world(; initial_capacity::Int = 128)
    return World(FBDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function firebenchmark_systems()
    return (InitFBSystem(), FBStepSystem(), FBTerminationSystem())
end

function firebenchmark_model(params::FBParams = FBParams())
    world = firebenchmark_world()
    _add_standard_resources!(world, params)
    add_resource!(world, FBGrid(params.grid_width, params.grid_height))
    add_resource!(world, FBStats())
    scheduler = Scheduler(world, firebenchmark_systems())
    initialize!(scheduler)
    return scheduler
end

struct FBObserver end

function firebenchmark_headers(::FBObserver)
    return ["BurnedTrees", "BurningCount"]
end

function firebenchmark_values(::FBObserver, world::World)
    stats = get_resource(world, FBStats)
    return Float64[stats.burned_trees, stats.burning_count]
end

function run_firebenchmark(; params::FBParams = FBParams(), observe::Bool = true)
    return _run_model(firebenchmark_model, FBObserver(), firebenchmark_values; params, observe)
end
