function tourism_world(; initial_capacity::Int = 512)
    World(
        TourismVisitor;
        initial_capacity = initial_capacity,
        allow_mutable = true
    )
end

function tourism_systems()
    return (
        InitTourismSystem(),
        TourismUpdateSystem(),
        TourismStatsSystem(),
        TourismTerminationSystem()
    )
end

function tourism_model(params::TourismParams = TourismParams())
    world = tourism_world()
    _add_standard_resources!(world, params)
    add_resource!(world, TourismStats())
    add_resource!(world, TourismState())
    scheduler = Scheduler(world, tourism_systems())
    initialize!(scheduler)
    return scheduler
end

struct TourismObserver end

function tourism_headers(::TourismObserver)
    return ["attendance", "reputation"]
end

function tourism_values(::TourismObserver, world::World)
    stats = get_resource(world, TourismStats)
    return Float64[Float64(stats.attendance), stats.reputation]
end

function run_tourism(; params::TourismParams = TourismParams(), observe::Bool = true)
    return _run_model(tourism_model, TourismObserver(), tourism_values; params, observe)
end
