function trafficgrid_world(; initial_capacity::Int = 4096)
    return World(TGCar; initial_capacity = initial_capacity, allow_mutable = true)
end

function trafficgrid_systems()
    return (InitTGSystem(), TGGoSystem(), TGTerminationSystem())
end

function trafficgrid_model(params::TGParams = TGParams())
    world = trafficgrid_world()
    _add_standard_resources!(world, params)
    # World size: -18..18 = 37x37 (matching NetLogo wrapper)
    w = 37
    h = 37
    gxi = Float64(w) / params.grid_size_x
    gyi = Float64(h) / params.grid_size_y
    add_resource!(world, TGRoad(w, h, gxi, gyi))
    add_resource!(world, TGStats())
    scheduler = Scheduler(world, trafficgrid_systems())
    initialize!(scheduler)
    return scheduler
end

struct TGObserver end

function trafficgrid_headers(::TGObserver)
    return ["NumCarsStopped", "MeanSpeed", "MeanWaitTime"]
end

function trafficgrid_values(::TGObserver, world::World)
    stats = get_resource(world, TGStats)
    return Float64[Float64(stats.num_cars_stopped), stats.mean_speed, stats.mean_wait_time]
end

function run_trafficgrid(; params::TGParams = TGParams(), observe::Bool = true)
    return _run_model(trafficgrid_model, TGObserver(), trafficgrid_values; params, observe)
end
