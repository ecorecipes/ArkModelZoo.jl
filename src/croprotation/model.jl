function croprotation_world(; initial_capacity::Int = 128)
    return World(CRDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function croprotation_systems()
    return (
        InitCRSystem(),
        CRWeeklySystem(),
        CRStatsSystem(),
        CRTerminationSystem(),
    )
end

function croprotation_model(params::CRParams = CRParams())
    world = croprotation_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, CRState(params.grid_size, params.grid_size))
    add_resource!(world, CRStats())
    scheduler = Scheduler(world, croprotation_systems())
    initialize!(scheduler)
    return scheduler
end

struct CRObserver end

function croprotation_headers(::CRObserver)
    return ["NActiveCrops"]
end

function croprotation_values(::CRObserver, world::World)
    stats = get_resource(world, CRStats)
    return Float64[Float64(stats.n_active_crops)]
end

function run_croprotation(; params::CRParams = CRParams(), observe::Bool = true)
    scheduler = croprotation_model(params)
    obs = CRObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, croprotation_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, croprotation_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
