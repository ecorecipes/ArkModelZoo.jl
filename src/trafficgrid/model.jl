function trafficgrid_world(; initial_capacity::Int = 4096)
    return World(TGCar; initial_capacity = initial_capacity, allow_mutable = true)
end

function trafficgrid_systems()
    return (InitTGSystem(), TGGoSystem(), TGTerminationSystem())
end

function trafficgrid_model(params::TGParams = TGParams())
    world = trafficgrid_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    w = params.grid_size_x * 7 + 1   # approximate world size
    h = params.grid_size_y * 7 + 1
    add_resource!(world, TGRoad(w, h))
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
    scheduler = trafficgrid_model(params)
    obs = TGObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, trafficgrid_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, trafficgrid_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
