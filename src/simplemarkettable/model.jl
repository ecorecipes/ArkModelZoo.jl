function simplemarkettable_world(; initial_capacity::Int = 128)
    return World(SMktTDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function simplemarkettable_systems()
    return (
        InitSMktTSystem(),
        SMktTGoSystem(),
        SMktTTerminationSystem(),
    )
end

function simplemarkettable_model(params::SMktTParams = SMktTParams())
    world = simplemarkettable_world()
    _add_standard_resources!(world, params)
    add_resource!(world, SMktTState())
    add_resource!(world, SMktTStats())
    scheduler = Scheduler(world, simplemarkettable_systems())
    initialize!(scheduler)
    return scheduler
end

struct SMktTObserver end

function simplemarkettable_headers(::SMktTObserver)
    return ["n_shoppers_alive", "total_paces"]
end

function simplemarkettable_values(::SMktTObserver, world::World)
    stats = get_resource(world, SMktTStats)
    return Float64[stats.n_shoppers_alive, stats.total_paces]
end

function run_simplemarkettable(; params::SMktTParams = SMktTParams(), observe::Bool = true)
    return _run_model(simplemarkettable_model, SMktTObserver(), simplemarkettable_values; params, observe)
end
