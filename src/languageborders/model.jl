function languageborders_world(; initial_capacity::Int = 128)
    return World(
        LanguageBordersDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function languageborders_systems()
    return (
        InitLanguageBordersSystem(),
        LanguageBordersUpdateSystem(),
        LanguageBordersTerminationSystem(),
    )
end

function languageborders_model(params::LanguageBordersParams = LanguageBordersParams())
    world = languageborders_world()
    _add_standard_resources!(world, params)
    add_resource!(world, LanguageBordersGrid(params.grid_width, params.grid_height))
    add_resource!(world, LanguageBordersStats())
    scheduler = Scheduler(world, languageborders_systems())
    initialize!(scheduler)
    return scheduler
end

struct LanguageBordersObserver end

function languageborders_headers(::LanguageBordersObserver)
    return ["AvgLanguage"]
end

function languageborders_values(::LanguageBordersObserver, world::World)
    stats = get_resource(world, LanguageBordersStats)
    return Float64[stats.avg_language]
end

function run_languageborders(; params::LanguageBordersParams = LanguageBordersParams(), observe::Bool = true)
    return _run_model(languageborders_model, LanguageBordersObserver(), languageborders_values; params, observe)
end
