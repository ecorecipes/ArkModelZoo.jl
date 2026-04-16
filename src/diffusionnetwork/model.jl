function diffusionnetwork_world(; initial_capacity::Int = 128)
    return World(DNDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function diffusionnetwork_systems()
    return (InitDiffusionNetworkSystem(), DNGoSystem(), DNTerminationSystem())
end

function diffusionnetwork_model(params::DiffusionNetworkParams = DiffusionNetworkParams())
    world = diffusionnetwork_world()
    _add_standard_resources!(world, params)
    add_resource!(world, DNNetwork())
    add_resource!(world, DNStats())
    scheduler = Scheduler(world, diffusionnetwork_systems())
    initialize!(scheduler)
    return scheduler
end

struct DNObserver end

function diffusionnetwork_headers(::DNObserver)
    return ["NumRedDN", "NumGreyDN"]
end

function diffusionnetwork_values(::DNObserver, world::World)
    stats = get_resource(world, DNStats)
    return Float64[stats.num_red, stats.num_grey]
end

function run_diffusionnetwork(; params::DiffusionNetworkParams = DiffusionNetworkParams(), observe::Bool = true)
    return _run_model(diffusionnetwork_model, DNObserver(), diffusionnetwork_values; params, observe)
end
