function prefattachhomophily_world(; initial_capacity::Int = 128)
    return World(PAHDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function prefattachhomophily_systems()
    return (InitPAHSystem(), PAHGoSystem(), PAHTerminationSystem())
end

function prefattachhomophily_model(params::PrefAttachHomophilyParams = PrefAttachHomophilyParams())
    world = prefattachhomophily_world()
    _add_standard_resources!(world, params)
    add_resource!(world, PAHNetwork())
    add_resource!(world, PAHStats())
    scheduler = Scheduler(world, prefattachhomophily_systems())
    initialize!(scheduler)
    return scheduler
end

struct PAHObserver end

function prefattachhomophily_headers(::PAHObserver)
    return ["NumberHomophily", "NumLinks"]
end

function prefattachhomophily_values(::PAHObserver, world::World)
    stats = get_resource(world, PAHStats)
    return Float64[stats.number_homophily, stats.num_links]
end

function run_prefattachhomophily(; params::PrefAttachHomophilyParams = PrefAttachHomophilyParams(), observe::Bool = true)
    return _run_model(prefattachhomophily_model, PAHObserver(), prefattachhomophily_values; params, observe)
end
