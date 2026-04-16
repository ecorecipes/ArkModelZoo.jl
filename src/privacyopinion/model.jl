function privacyopinion_world(; initial_capacity::Int = 128)
    return World(PrvDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function privacyopinion_systems()
    return (
        InitPrvSystem(),
        PrvPropagateSystem(),
        PrvBlockUpdateSystem(),
        PrvCheckAdoptersSystem(),
        PrvHRSystem(),
        PrvPVSystem(),
        PrvTerminationSystem(),
    )
end

function privacyopinion_model(params::PrvParams = PrvParams())
    world = privacyopinion_world()
    n = params.rows * params.cols
    _add_standard_resources!(world, params)
    add_resource!(world, PrvNetwork(n))
    add_resource!(world, PrvCounters(params.hr_minimum_tick_interval, params.privacy_minimum_tick_interval))
    add_resource!(world, PrvStats())
    scheduler = Scheduler(world, privacyopinion_systems())
    initialize!(scheduler)
    return scheduler
end

struct PrvObserver end

function privacyopinion_headers(::PrvObserver)
    return ["AdoptersTotal", "AdopterPercent"]
end

function privacyopinion_values(::PrvObserver, world::World)
    stats = get_resource(world, PrvStats)
    return Float64[Float64(stats.adopters_total), stats.adopter_percent]
end

function run_privacyopinion(; params::PrvParams = PrvParams(), observe::Bool = true)
    return _run_model(privacyopinion_model, PrvObserver(), privacyopinion_values; params, observe)
end
