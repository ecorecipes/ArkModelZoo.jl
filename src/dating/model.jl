function dating_world(; initial_capacity::Int = 128)
    return World(DatingDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function dating_systems()
    return (
        InitDatingSystem(),
        DatingMoveSystem(),
        DatingInteractSystem(),
        DatingTerminationSystem(),
    )
end

function dating_model(params::DatingParams = DatingParams())
    world = dating_world()
    _add_standard_resources!(world, params)
    add_resource!(world, DatingState())
    add_resource!(world, DatingGrid(params.grid_size, params.grid_size))
    add_resource!(world, DatingStats())
    scheduler = Scheduler(world, dating_systems())
    initialize!(scheduler)
    return scheduler
end

struct DatingObserver end

function dating_headers(::DatingObserver)
    return ["NPaired"]
end

function dating_values(::DatingObserver, world::World)
    stats = get_resource(world, DatingStats)
    return Float64[stats.n_paired]
end

function run_dating(; params::DatingParams = DatingParams(), observe::Bool = true)
    return _run_model(dating_model, DatingObserver(), dating_values; params, observe)
end
