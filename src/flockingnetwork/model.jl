function flockingnetwork_world(; initial_capacity::Int = 256)
    return World(FNPosition, FNHeading, FNTag; initial_capacity = initial_capacity, allow_mutable = true)
end

function flockingnetwork_systems()
    return (InitFlockingNetworkSystem(), FNFlockSystem(), FNTerminationSystem())
end

function flockingnetwork_model(params::FlockingNetworkParams = FlockingNetworkParams())
    world = flockingnetwork_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = flockingnetwork_model(params)
    obs = FNObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, flockingnetwork_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, flockingnetwork_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
