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
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = sleuthlanduse_model(params)
    obs = SleuthObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, sleuthlanduse_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, sleuthlanduse_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
