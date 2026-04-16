function dlasimple_world(; initial_capacity::Int = 4096)
    return World(DLAsPosition, DLAsHeading; initial_capacity = initial_capacity, allow_mutable = true)
end

function dlasimple_systems()
    return (InitDLAsSystem(), DLAsUpdateSystem(), DLAsStatsSystem(), DLAsTerminationSystem())
end

function dlasimple_model(params::DLAsParams = DLAsParams())
    world = dlasimple_world()
    _add_standard_resources!(world, params)
    add_resource!(world, DLAsGrid(params.grid_width, params.grid_height))
    add_resource!(world, DLAsStats())
    scheduler = Scheduler(world, dlasimple_systems())
    initialize!(scheduler)
    return scheduler
end

struct DLAsObserver end

function dlasimple_headers(::DLAsObserver)
    return ["NRemaining"]
end

function dlasimple_values(::DLAsObserver, world::World)
    stats = get_resource(world, DLAsStats)
    return Float64[stats.n_remaining]
end

function run_dlasimple(; params::DLAsParams = DLAsParams(), observe::Bool = true)
    return _run_model(dlasimple_model, DLAsObserver(), dlasimple_values; params, observe)
end
