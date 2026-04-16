function flocking_world(; initial_capacity::Int = 2048)
    return World(
        FlockPosition,
        FlockHeading;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function flocking_systems()
    return (
        InitFlockingSystem(),
        FlockSystem(),
        FlockMoveSystem(),
        FlockStatsSystem(),
        FlockTerminationSystem(),
    )
end

function flocking_model(params::FlockingParams = FlockingParams())
    world = flocking_world()
    _add_standard_resources!(world, params)
    add_resource!(world, FlockStats())
    scheduler = Scheduler(world, flocking_systems())
    initialize!(scheduler)
    return scheduler
end

struct FlockingObserver end

function flocking_headers(::FlockingObserver)
    return ["AvgHeading"]
end

function flocking_values(::FlockingObserver, world::World)
    stats = get_resource(world, FlockStats)
    return Float64[stats.avg_heading]
end

function run_flocking(; params::FlockingParams = FlockingParams(), observe::Bool = true)
    return _run_model(flocking_model, FlockingObserver(), flocking_values; params, observe)
end
