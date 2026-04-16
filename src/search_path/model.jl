function search_path_world(; initial_capacity::Int = 16)
    return World(
        SearchPathCell,
        SearchPathStatus,
        SearchPathSearcher,
        SearchPathTarget;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function search_path_systems()
    return (
        InitSearchPathSystem(),
        SearchPathSearcherMoveSystem(),
        SearchPathTargetMoveSystem(),
        SearchPathCatchSystem(),
        SearchPathStatsSystem(),
        SearchPathTerminationSystem(),
    )
end

function search_path_model(params::SearchPathParams = SearchPathParams())
    world = search_path_world()
    _add_standard_resources!(world, params)
    add_resource!(world, SearchPathStats())
    scheduler = Scheduler(world, search_path_systems())
    initialize!(scheduler)
    return scheduler
end

struct SearchPathObserver end

function search_path_headers(::SearchPathObserver)
    return ["NumberCaught", "Time"]
end

function search_path_values(::SearchPathObserver, world::World)
    stats = get_resource(world, SearchPathStats)
    tick = get_resource(world, Tick)
    return Float64[stats.number_caught, tick.tick]
end

function run_search_path(; params::SearchPathParams = SearchPathParams(), observe::Bool = true)
    return _run_model(search_path_model, SearchPathObserver(), search_path_values; params, observe)
end
