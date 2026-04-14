function trafficintersection_world(; initial_capacity::Int = 4096)
    return World(TICar; initial_capacity = initial_capacity, allow_mutable = true)
end

function trafficintersection_systems()
    return (InitTISystem(), TIGoSystem(), TITerminationSystem())
end

function trafficintersection_model(params::TIParams = TIParams())
    world = trafficintersection_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = trafficintersection_model(params)
    obs = TIObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, trafficintersection_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, trafficintersection_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
