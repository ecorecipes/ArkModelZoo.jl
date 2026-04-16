function trafficbasic_world(; initial_capacity::Int = 64)
    return World(
        TBDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function trafficbasic_systems()
    return (
        InitTBSystem(),
        TBGoSystem(),
        TBTerminationSystem(),
    )
end

function trafficbasic_model(params::TBParams = TBParams())
    world = trafficbasic_world()
    _add_standard_resources!(world, params)
    add_resource!(world, TBRoad(params.road_length))
    add_resource!(world, TBStats())
    scheduler = Scheduler(world, trafficbasic_systems())
    initialize!(scheduler)
    return scheduler
end

struct TBObserver end

function trafficbasic_headers(::TBObserver)
    return ["mean-speed"]
end

function trafficbasic_values(::TBObserver, world::World)
    stats = get_resource(world, TBStats)
    return Float64[stats.mean_speed]
end

function run_trafficbasic(; params::TBParams = TBParams(), observe::Bool = true)
    return _run_model(trafficbasic_model, TBObserver(), trafficbasic_values; params, observe)
end
