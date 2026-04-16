function sugarscapeculture_world(; initial_capacity::Int = 128)
    return World(SCDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function sugarscapeculture_systems()
    return (InitSCSystem(), SCGoSystem(), SCTerminationSystem())
end

function sugarscapeculture_model(params::SCParams = SCParams())
    world = sugarscapeculture_world()
    _add_standard_resources!(world, params)
    add_resource!(world, SCWorld(params.grid_width, params.grid_height))
    add_resource!(world, SCStats())
    scheduler = Scheduler(world, sugarscapeculture_systems())
    initialize!(scheduler)
    return scheduler
end

struct SCObserver end

function sugarscapeculture_headers(::SCObserver)
    return ["num_red", "num_blue"]
end

function sugarscapeculture_values(::SCObserver, world::World)
    stats = get_resource(world, SCStats)
    return Float64[stats.num_red, stats.num_blue]
end

function run_sugarscapeculture(; params::SCParams = SCParams(), observe::Bool = true)
    return _run_model(sugarscapeculture_model, SCObserver(), sugarscapeculture_values; params, observe)
end
