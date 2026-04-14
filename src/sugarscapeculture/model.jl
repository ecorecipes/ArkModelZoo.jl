function sugarscapeculture_world(; initial_capacity::Int = 128)
    return World(SCDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function sugarscapeculture_systems()
    return (InitSCSystem(), SCGoSystem(), SCTerminationSystem())
end

function sugarscapeculture_model(params::SCParams = SCParams())
    world = sugarscapeculture_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, SCWorld(params.grid_width, params.grid_height))
    add_resource!(world, SCStats())
    scheduler = Scheduler(world, sugarscapeculture_systems())
    initialize!(scheduler)
    return scheduler
end

struct SCObserver end

function sugarscapeculture_headers(::SCObserver)
    return ["num_red", "num_blue"]
end

function sugarscapeculture_values(::SCObserver, world::World)
    stats = get_resource(world, SCStats)
    return Float64[stats.num_red, stats.num_blue]
end

function run_sugarscapeculture(; params::SCParams = SCParams(), observe::Bool = true)
    scheduler = sugarscapeculture_model(params)
    obs = SCObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, sugarscapeculture_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, sugarscapeculture_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
