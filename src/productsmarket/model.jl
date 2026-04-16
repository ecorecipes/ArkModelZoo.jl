function productsmarket_world(; initial_capacity::Int = 128)
    return World(PMktDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function productsmarket_systems()
    return (InitPMktSystem(), PMktGoSystem(), PMktTerminationSystem())
end

function productsmarket_model(params::PMktParams = PMktParams())
    world = productsmarket_world()
    _add_standard_resources!(world, params)
    add_resource!(world, PMktNetwork())
    add_resource!(world, PMktStats())
    scheduler = Scheduler(world, productsmarket_systems())
    initialize!(scheduler)
    return scheduler
end

struct PMktObserver end

function productsmarket_headers(::PMktObserver)
    return ["CountApple", "CountSamsung"]
end

function productsmarket_values(::PMktObserver, world::World)
    stats = get_resource(world, PMktStats)
    return Float64[stats.count_apple, stats.count_samsung]
end

function run_productsmarket(; params::PMktParams = PMktParams(), observe::Bool = true)
    return _run_model(productsmarket_model, PMktObserver(), productsmarket_values; params, observe)
end
