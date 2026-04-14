function fakenews_world(; initial_capacity::Int = 128)
    return World(FNewsDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function fakenews_systems()
    return (InitFNewsSystem(), FNewsGoSystem(), FNewsTerminationSystem())
end

function fakenews_model(params::FNewsParams = FNewsParams())
    world = fakenews_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, FNewsNetwork())
    add_resource!(world, FNewsStats())
    scheduler = Scheduler(world, fakenews_systems())
    initialize!(scheduler)
    return scheduler
end

struct FNewsObserver end

function fakenews_headers(::FNewsObserver)
    return ["PctAware", "PctUnaware"]
end

function fakenews_values(::FNewsObserver, world::World)
    stats = get_resource(world, FNewsStats)
    return Float64[stats.pct_aware, stats.pct_unaware]
end

function run_fakenews(; params::FNewsParams = FNewsParams(), observe::Bool = true)
    scheduler = fakenews_model(params)
    obs = FNewsObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, fakenews_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, fakenews_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
