function hikingelevation_world(; initial_capacity::Int = 1024)
    return World(
        HikePosition,
        HikeState,
        HikerTag;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function hikingelevation_systems()
    return (
        InitHikeSystem(),
        HikeSpawnSystem(),
        HikeMoveSystem(),
        HikeStatsSystem(),
        HikeTerminationSystem(),
    )
end

function hikingelevation_model(params::HikeParams = HikeParams())
    world = hikingelevation_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, HikeGrid(262, 184))
    add_resource!(world, HikeStats())
    scheduler = Scheduler(world, hikingelevation_systems())
    initialize!(scheduler)
    return scheduler
end

struct HikeObserver end

function hikingelevation_headers(::HikeObserver)
    return ["TrackElevation"]
end

function hikingelevation_values(::HikeObserver, world::World)
    stats = get_resource(world, HikeStats)
    return Float64[stats.track_elevation]
end

function run_hikingelevation(; params::HikeParams = HikeParams(), observe::Bool = true)
    scheduler = hikingelevation_model(params)
    obs = HikeObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, hikingelevation_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, hikingelevation_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
