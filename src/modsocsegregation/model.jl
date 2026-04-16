function modsocsegregation_world(; initial_capacity::Int = 4096)
    return World(
        ModsocPosition, ModsocColor, ModsocHappiness;
        initial_capacity = initial_capacity, allow_mutable = true,
    )
end

function modsocsegregation_systems()
    return (InitModsocSystem(), ModsocMoveSystem(), ModsocTerminationSystem())
end

function modsocsegregation_model(params::ModsocSegParams = ModsocSegParams())
    world = modsocsegregation_world()
    _add_standard_resources!(world, params)
    add_resource!(world, ModsocGrid(params.grid_width, params.grid_height))
    add_resource!(world, ModsocStats())
    scheduler = Scheduler(world, modsocsegregation_systems())
    initialize!(scheduler)
    return scheduler
end

struct ModsocSegObserver end

function modsocsegregation_headers(::ModsocSegObserver)
    return ["AverageSimilarity", "Unhappiness"]
end

function modsocsegregation_values(::ModsocSegObserver, world::World)
    stats = get_resource(world, ModsocStats)
    return Float64[stats.average_similarity, stats.unhappiness]
end

function run_modsocsegregation(; params::ModsocSegParams = ModsocSegParams(), observe::Bool = true)
    return _run_model(modsocsegregation_model, ModsocSegObserver(), modsocsegregation_values; params, observe)
end
