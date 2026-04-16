function rationalevolvingpd_world(; initial_capacity::Int = 128)
    return World(REPDDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function rationalevolvingpd_systems()
    return (
        InitREPDSystem(),
        REPDFindPartnersSystem(),
        REPDPlaySystem(),
        REPDEnergySystem(),
        REPDReproduceSystem(),
        REPDDeathSystem(),
        REPDStatsSystem(),
        REPDTerminationSystem(),
    )
end

function rationalevolvingpd_model(params::REPDParams = REPDParams())
    world = rationalevolvingpd_world()
    _add_standard_resources!(world, params)
    add_resource!(world, REPDState(params.grid_size, params.grid_size))
    add_resource!(world, REPDStats())
    scheduler = Scheduler(world, rationalevolvingpd_systems())
    initialize!(scheduler)
    return scheduler
end

struct REPDObserver end

function rationalevolvingpd_headers(::REPDObserver)
    return ["NAlive", "NNeurons"]
end

function rationalevolvingpd_values(::REPDObserver, world::World)
    stats = get_resource(world, REPDStats)
    return Float64[Float64(stats.n_alive), Float64(stats.n_neurons)]
end

function run_rationalevolvingpd(; params::REPDParams = REPDParams(), observe::Bool = true)
    return _run_model(rationalevolvingpd_model, REPDObserver(), rationalevolvingpd_values; params, observe)
end
