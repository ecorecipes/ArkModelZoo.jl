function ff_world(; initial_capacity::Int = 4096)
    return World(FFFirefly; initial_capacity = initial_capacity, allow_mutable = true)
end

function ff_systems()
    return (InitFFSystem(), FFGoSystem(), FFTerminationSystem())
end

function ff_model(params::FFParams = FFParams())
    world = ff_world()
    _add_standard_resources!(world, params)
    add_resource!(world, FFStats())
    scheduler = Scheduler(world, ff_systems())
    initialize!(scheduler)
    return scheduler
end

struct FFObserver end

function ff_headers(::FFObserver)
    return ["NumFlashing"]
end

function ff_values(::FFObserver, world::World)
    stats = get_resource(world, FFStats)
    return Float64[Float64(stats.num_flashing)]
end

function run_fireflies(; params::FFParams = FFParams(), observe::Bool = true)
    return _run_model(ff_model, FFObserver(), ff_values; params, observe)
end
