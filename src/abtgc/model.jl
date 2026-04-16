function abtgc_world(; initial_capacity::Int = 128)
    return World(ABTDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function abtgc_systems()
    return (
        InitABTSystem(),
        ABTGoSystem(),
        ABTTerminationSystem(),
    )
end

function abtgc_model(params::ABTParams = ABTParams())
    world = abtgc_world()
    _add_standard_resources!(world, params)
    add_resource!(world, ABTState())
    add_resource!(world, ABTStats())
    scheduler = Scheduler(world, abtgc_systems())
    initialize!(scheduler)
    return scheduler
end

struct ABTObserver end

function abtgc_headers(::ABTObserver)
    return ["bad_links", "unhandled_messages"]
end

function abtgc_values(::ABTObserver, world::World)
    stats = get_resource(world, ABTStats)
    return Float64[stats.bad_links, stats.unhandled_messages]
end

function run_abtgc(; params::ABTParams = ABTParams(), observe::Bool = true)
    return _run_model(abtgc_model, ABTObserver(), abtgc_values; params, observe)
end
