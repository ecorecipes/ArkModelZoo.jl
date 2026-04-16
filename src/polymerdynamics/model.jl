function polymerdynamics_world(; initial_capacity::Int = 128)
    return World(
        PolymerDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function polymerdynamics_systems()
    return (
        InitPolymerSystem(),
        PolymerUpdateSystem(),
        PolymerTerminationSystem(),
    )
end

function polymerdynamics_model(params::PolymerDynamicsParams = PolymerDynamicsParams())
    world = polymerdynamics_world()
    _add_standard_resources!(world, params)
    add_resource!(world, PolymerGrid(params.grid_width, params.grid_height))
    add_resource!(world, PolymerStats())
    scheduler = Scheduler(world, polymerdynamics_systems())
    initialize!(scheduler)
    return scheduler
end

struct PolymerDynamicsObserver end

function polymerdynamics_headers(::PolymerDynamicsObserver)
    return ["NTurtles"]
end

function polymerdynamics_values(::PolymerDynamicsObserver, world::World)
    stats = get_resource(world, PolymerStats)
    return Float64[stats.n_turtles]
end

function run_polymerdynamics(; params::PolymerDynamicsParams = PolymerDynamicsParams(), observe::Bool = true)
    return _run_model(polymerdynamics_model, PolymerDynamicsObserver(), polymerdynamics_values; params, observe)
end
