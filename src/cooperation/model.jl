function cooperation_world(; initial_capacity::Int = 4096)
    return World(
        COOPPosition,
        COOPCowType,
        COOPEnergy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function cooperation_systems()
    return (
        InitCOOPSystem(),
        COOPGoSystem(),
        COOPTerminationSystem(),
    )
end

function cooperation_model(params::COOPParams = COOPParams())
    world = cooperation_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, COOPGrassGrid(params.grid_width, params.grid_height))
    add_resource!(world, COOPStats())
    scheduler = Scheduler(world, cooperation_systems())
    initialize!(scheduler)
    return scheduler
end

struct COOPObserver end

function cooperation_headers(::COOPObserver)
    return ["NumCooperative", "NumGreedy"]
end

function cooperation_values(::COOPObserver, world::World)
    stats = get_resource(world, COOPStats)
    return Float64[stats.num_cooperative, stats.num_greedy]
end

function run_cooperation(; params::COOPParams = COOPParams(), observe::Bool = true)
    scheduler = cooperation_model(params)
    obs = COOPObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, cooperation_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, cooperation_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
