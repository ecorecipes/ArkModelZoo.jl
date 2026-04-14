function prefattachhomophily_world(; initial_capacity::Int = 128)
    return World(PAHDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function prefattachhomophily_systems()
    return (InitPAHSystem(), PAHGoSystem(), PAHTerminationSystem())
end

function prefattachhomophily_model(params::PrefAttachHomophilyParams = PrefAttachHomophilyParams())
    world = prefattachhomophily_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = prefattachhomophily_model(params)
    obs = PAHObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, prefattachhomophily_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, prefattachhomophily_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
