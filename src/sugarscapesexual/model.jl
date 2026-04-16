function sugarscapesexual_world(; initial_capacity::Int = 1024)
    return World(SSDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function sugarscapesexual_systems()
    return (
        InitSSSystem(),
        SSGoSystem(),
        SSTerminationSystem(),
    )
end

function sugarscapesexual_model(params::SSParams = SSParams())
    world = sugarscapesexual_world()
    _add_standard_resources!(world, params)
    add_resource!(world, SSWorld(params.grid_width, params.grid_height))
    add_resource!(world, SSStats())
    scheduler = Scheduler(world, sugarscapesexual_systems())
    initialize!(scheduler)
    return scheduler
end

struct SSObserver end

function sugarscapesexual_headers(::SSObserver)
    return ["NumTurtles"]
end

function sugarscapesexual_values(::SSObserver, world::World)
    stats = get_resource(world, SSStats)
    return Float64[stats.num_turtles]
end

function run_sugarscapesexual(; params::SSParams = SSParams(), observe::Bool = true)
    return _run_model(sugarscapesexual_model, SSObserver(), sugarscapesexual_values; params, observe)
end
