function sleuthlanduse_world(; initial_capacity::Int = 128)
    return World(
        SleuthDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function sleuthlanduse_systems()
    return (
        InitSleuthSystem(),
        SleuthGrowthSystem(),
        SleuthStatsSystem(),
        SleuthTerminationSystem(),
    )
end

function sleuthlanduse_model(params::SleuthParams = SleuthParams())
    world = sleuthlanduse_world()
    _add_standard_resources!(world, params)
    add_resource!(world, SleuthGrid(params.grid_width, params.grid_height))
    add_resource!(world, SleuthStats())
    scheduler = Scheduler(world, sleuthlanduse_systems())
    initialize!(scheduler)
    return scheduler
end

struct SleuthObserver end

function sleuthlanduse_headers(::SleuthObserver)
    return ["UrbanTotal", "PctUrban", "Concentration"]
end

function sleuthlanduse_values(::SleuthObserver, world::World)
    stats = get_resource(world, SleuthStats)
    return Float64[stats.urbantotal, stats.purbantotal, stats.concentration]
end

function run_sleuthlanduse(; params::SleuthParams = SleuthParams(), observe::Bool = true)
    return _run_model(sleuthlanduse_model, SleuthObserver(), sleuthlanduse_values; params, observe)
end
