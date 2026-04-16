function minoritybelief_world(; initial_capacity::Int = 128)
    return World(MBeliefDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function minoritybelief_systems()
    return (
        InitMBeliefSystem(),
        MBeliefGoSystem(),
        MBeliefTerminationSystem(),
    )
end

function minoritybelief_model(params::MBeliefParams = MBeliefParams())
    world = minoritybelief_world()
    _add_standard_resources!(world, params)
    add_resource!(world, MBeliefState())
    add_resource!(world, MBeliefStats())
    scheduler = Scheduler(world, minoritybelief_systems())
    initialize!(scheduler)
    return scheduler
end

struct MBeliefObserver end

function minoritybelief_headers(::MBeliefObserver)
    return ["n_magenta", "n_yellow", "n_cyan"]
end

function minoritybelief_values(::MBeliefObserver, world::World)
    stats = get_resource(world, MBeliefStats)
    return Float64[stats.n_magenta, stats.n_yellow, stats.n_cyan]
end

function run_minoritybelief(; params::MBeliefParams = MBeliefParams(), observe::Bool = true)
    return _run_model(minoritybelief_model, MBeliefObserver(), minoritybelief_values; params, observe)
end
