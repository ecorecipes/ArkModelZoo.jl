function rumormill_world(; initial_capacity::Int = 128)
    return World(
        RMDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function rumormill_systems()
    return (
        InitRMSystem(),
        RMGoSystem(),
        RMTerminationSystem(),
    )
end

function rumormill_model(params::RMParams = RMParams())
    world = rumormill_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, RMGrid(params.grid_width, params.grid_height))
    add_resource!(world, RMStats())
    scheduler = Scheduler(world, rumormill_systems())
    initialize!(scheduler)
    return scheduler
end

struct RMObserver end

function rumormill_headers(::RMObserver)
    return ["clique"]
end

function rumormill_values(::RMObserver, world::World)
    stats = get_resource(world, RMStats)
    return Float64[stats.clique]
end

function run_rumormill(; params::RMParams = RMParams(), observe::Bool = true)
    scheduler = rumormill_model(params)
    obs = RMObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, rumormill_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, rumormill_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
