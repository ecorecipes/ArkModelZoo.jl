function dla_world(; initial_capacity::Int = 4096)
    return World(
        DLAPosition,
        DLAHeading;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function dla_systems()
    return (
        InitDLASystem(),
        DLAUpdateSystem(),
        DLAStatsSystem(),
        DLATerminationSystem(),
    )
end

function dla_model(params::DLAParams = DLAParams())
    world = dla_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, DLAGrid(params.grid_width, params.grid_height))
    add_resource!(world, DLAStats())
    scheduler = Scheduler(world, dla_systems())
    initialize!(scheduler)
    return scheduler
end

struct DLAObserver end

function dla_headers(::DLAObserver)
    return ["NRemaining"]
end

function dla_values(::DLAObserver, world::World)
    stats = get_resource(world, DLAStats)
    return Float64[stats.n_remaining]
end

function run_dla(; params::DLAParams = DLAParams(), observe::Bool = true)
    scheduler = dla_model(params)
    obs = DLAObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, dla_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, dla_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
