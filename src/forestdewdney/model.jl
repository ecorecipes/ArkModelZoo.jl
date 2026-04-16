function forestdewdney_world(; initial_capacity::Int = 256)
    return World(
        FDDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function forestdewdney_systems()
    return (
        InitFDSystem(),
        FDGoSystem(),
        FDTerminationSystem(),
    )
end

function forestdewdney_model(params::FDParams = FDParams())
    world = forestdewdney_world()
    _add_standard_resources!(world, params)
    add_resource!(world, FDForest(params.grid_width, params.grid_height))
    add_resource!(world, FDStats())
    scheduler = Scheduler(world, forestdewdney_systems())
    initialize!(scheduler)
    return scheduler
end

struct FDObserver end

function forestdewdney_headers(::FDObserver)
    return ["local_richness", "sp"]
end

function forestdewdney_values(::FDObserver, world::World)
    stats = get_resource(world, FDStats)
    return Float64[stats.local_richness, stats.sp]
end

function run_forestdewdney(; params::FDParams = FDParams(), observe::Bool = true)
    return _run_model(forestdewdney_model, FDObserver(), forestdewdney_values; params, observe)
end
