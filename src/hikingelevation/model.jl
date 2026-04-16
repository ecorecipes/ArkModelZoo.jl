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
    _add_standard_resources!(world, params)
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
    return _run_model(hikingelevation_model, HikeObserver(), hikingelevation_values; params, observe)
end
