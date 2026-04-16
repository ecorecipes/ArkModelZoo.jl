function traffic2lanes_world(; initial_capacity::Int = 4096)
    return World(T2LCar; initial_capacity = initial_capacity, allow_mutable = true)
end

function traffic2lanes_systems()
    return (InitT2LSystem(), T2LGoSystem(), T2LTerminationSystem())
end

function traffic2lanes_model(params::T2LParams = T2LParams())
    world = traffic2lanes_world()
    _add_standard_resources!(world, params)
    add_resource!(world, T2LRoad(params.road_length))
    add_resource!(world, T2LStats())
    scheduler = Scheduler(world, traffic2lanes_systems())
    initialize!(scheduler)
    return scheduler
end

struct T2LObserver end

function traffic2lanes_headers(::T2LObserver)
    return ["MeanSpeed", "NumLaneChanges"]
end

function traffic2lanes_values(::T2LObserver, world::World)
    stats = get_resource(world, T2LStats)
    return Float64[stats.mean_speed, Float64(stats.num_lane_changes)]
end

function run_traffic2lanes(; params::T2LParams = T2LParams(), observe::Bool = true)
    return _run_model(traffic2lanes_model, T2LObserver(), traffic2lanes_values; params, observe)
end
