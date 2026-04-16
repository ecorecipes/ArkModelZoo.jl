function s1g_world(; initial_capacity::Int = 1024)
    return World(S1GAgent; initial_capacity = initial_capacity, allow_mutable = true)
end

function s1g_systems()
    return (
        InitS1GSystem(),
        S1GGoSystem(),
        S1GTerminationSystem(),
    )
end

function s1g_model(params::S1GParams = S1GParams())
    world = s1g_world()
    _add_standard_resources!(world, params)
    add_resource!(world, S1GGrid(params.grid_width, params.grid_height))
    add_resource!(world, S1GStats())
    scheduler = Scheduler(world, s1g_systems())
    initialize!(scheduler)
    return scheduler
end

struct S1GObserver end

function s1g_headers(::S1GObserver)
    return ["Population", "MeanSugar", "MaxSugar", "MinSugar"]
end

function s1g_values(::S1GObserver, world::World)
    stats = get_resource(world, S1GStats)
    return Float64[stats.population, stats.mean_sugar, stats.max_sugar, stats.min_sugar]
end

function run_sugarscape_1_growback(; params::S1GParams = S1GParams(), observe::Bool = true)
    return _run_model(s1g_model, S1GObserver(), s1g_values; params, observe)
end
