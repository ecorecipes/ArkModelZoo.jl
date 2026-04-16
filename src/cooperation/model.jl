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
    _add_standard_resources!(world, params)
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
    return _run_model(cooperation_model, COOPObserver(), cooperation_values; params, observe)
end
