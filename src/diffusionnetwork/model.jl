function diffusionnetwork_world(; initial_capacity::Int = 128)
    return World(DNDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function diffusionnetwork_systems()
    return (InitDiffusionNetworkSystem(), DNGoSystem(), DNTerminationSystem())
end

function diffusionnetwork_model(params::DiffusionNetworkParams = DiffusionNetworkParams())
    world = diffusionnetwork_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = diffusionnetwork_model(params)
    obs = DNObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, diffusionnetwork_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, diffusionnetwork_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
