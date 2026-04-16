function flockingnetwork_world(; initial_capacity::Int = 256)
    return World(FNPosition, FNHeading, FNTag; initial_capacity = initial_capacity, allow_mutable = true)
end

function flockingnetwork_systems()
    return (InitFlockingNetworkSystem(), FNFlockSystem(), FNTerminationSystem())
end

function flockingnetwork_model(params::FlockingNetworkParams = FlockingNetworkParams())
    world = flockingnetwork_world()
    _add_standard_resources!(world, params)
    add_resource!(world, FNStats())
    scheduler = Scheduler(world, flockingnetwork_systems())
    initialize!(scheduler)
    return scheduler
end

struct FNObserver end

function flockingnetwork_headers(::FNObserver)
    return ["NumLinksFN", "AvgHeadingFN"]
end

function flockingnetwork_values(::FNObserver, world::World)
    stats = get_resource(world, FNStats)
    return Float64[stats.num_links, stats.avg_heading]
end

function run_flockingnetwork(; params::FlockingNetworkParams = FlockingNetworkParams(), observe::Bool = true)
    return _run_model(flockingnetwork_model, FNObserver(), flockingnetwork_values; params, observe)
end
