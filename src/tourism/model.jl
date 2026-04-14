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
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = tourism_model(params)
    obs = TourismObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, tourism_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, tourism_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
