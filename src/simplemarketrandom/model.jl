function simplemarketrandom_world(; initial_capacity::Int = 128)
    return World(SMktRDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function simplemarketrandom_systems()
    return (
        InitSMktRSystem(),
        SMktRGoSystem(),
        SMktRTerminationSystem(),
    )
end

function simplemarketrandom_model(params::SMktRParams = SMktRParams())
    world = simplemarketrandom_world()
    _add_standard_resources!(world, params)
    add_resource!(world, SMktRState())
    add_resource!(world, SMktRStats())
    scheduler = Scheduler(world, simplemarketrandom_systems())
    initialize!(scheduler)
    return scheduler
end

struct SMktRObserver end

function simplemarketrandom_headers(::SMktRObserver)
    return ["num_shoppers_left", "num_traders_with_stock"]
end

function simplemarketrandom_values(::SMktRObserver, world::World)
    stats = get_resource(world, SMktRStats)
    return Float64[stats.num_shoppers_left, stats.num_traders_with_stock]
end

function run_simplemarketrandom(; params::SMktRParams = SMktRParams(), observe::Bool = true)
    return _run_model(simplemarketrandom_model, SMktRObserver(), simplemarketrandom_values; params, observe)
end
