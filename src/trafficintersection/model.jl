function trafficintersection_world(; initial_capacity::Int = 4096)
    return World(TICar; initial_capacity = initial_capacity, allow_mutable = true)
end

function trafficintersection_systems()
    return (InitTISystem(), TIGoSystem(), TITerminationSystem())
end

function trafficintersection_model(params::TIParams = TIParams())
    world = trafficintersection_world()
    _add_standard_resources!(world, params)
    add_resource!(world, TIRoad(params.grid_size))
    add_resource!(world, TIStats())
    scheduler = Scheduler(world, trafficintersection_systems())
    initialize!(scheduler)
    return scheduler
end

struct TIObserver end

function trafficintersection_headers(::TIObserver)
    return ["WaitingOverall", "WaitingEastbound", "WaitingNorthbound"]
end

function trafficintersection_values(::TIObserver, world::World)
    stats = get_resource(world, TIStats)
    return Float64[Float64(stats.waiting_overall), Float64(stats.waiting_eastbound), Float64(stats.waiting_northbound)]
end

function run_trafficintersection(; params::TIParams = TIParams(), observe::Bool = true)
    return _run_model(trafficintersection_model, TIObserver(), trafficintersection_values; params, observe)
end
