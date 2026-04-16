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
    _add_standard_resources!(world, params)
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
    return _run_model(croprotation_model, CRObserver(), croprotation_values; params, observe)
end
