function blackbox_world(; initial_capacity::Int = 128)
    return World(BBoxDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function blackbox_systems()
    return (InitBBoxSystem(), BBoxGoSystem(), BBoxTerminationSystem())
end

function blackbox_model(params::BBoxParams = BBoxParams())
    world = blackbox_world()
    _add_standard_resources!(world, params)
    add_resource!(world, BBoxGrid(params.grid_size, params.grid_size))
    add_resource!(world, BBoxStats())
    scheduler = Scheduler(world, blackbox_systems())
    initialize!(scheduler)
    return scheduler
end

struct BBoxObserver end

function blackbox_headers(::BBoxObserver)
    return ["Q4t", "Q3t"]
end

function blackbox_values(::BBoxObserver, world::World)
    stats = get_resource(world, BBoxStats)
    return Float64[stats.q4t, stats.q3t]
end

function run_blackbox(; params::BBoxParams = BBoxParams(), observe::Bool = true)
    return _run_model(blackbox_model, BBoxObserver(), blackbox_values; params, observe)
end
