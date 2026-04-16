function axelrodcultural_world(; initial_capacity::Int = 128)
    return World(
        AxelrodDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function axelrodcultural_systems()
    return (
        InitAxelrodSystem(),
        AxelrodUpdateSystem(),
        AxelrodStatsSystem(),
        AxelrodTerminationSystem(),
    )
end

function axelrodcultural_model(params::AxelrodParams = AxelrodParams())
    world = axelrodcultural_world()
    _add_standard_resources!(world, params)
    add_resource!(world, AxelrodGrid(params.world_size, params.world_size, params.F))
    add_resource!(world, AxelrodStats())
    scheduler = Scheduler(world, axelrodcultural_systems())
    initialize!(scheduler)
    return scheduler
end

struct AxelrodObserver end

function axelrodcultural_headers(::AxelrodObserver)
    return ["NumberOfCultures", "NumberOfActiveAgents"]
end

function axelrodcultural_values(::AxelrodObserver, world::World)
    stats = get_resource(world, AxelrodStats)
    return Float64[stats.number_of_cultures, stats.number_of_active_agents]
end

function run_axelrodcultural(; params::AxelrodParams = AxelrodParams(), observe::Bool = true)
    return _run_model(axelrodcultural_model, AxelrodObserver(), axelrodcultural_values; params, observe)
end
