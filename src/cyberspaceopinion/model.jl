function cyber_world(; initial_capacity::Int = 128)
    return World(CyberDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function cyber_systems()
    return (
        InitCyberSystem(),
        CyberSpreadSystem(),
        CyberRecoverSystem(),
        CyberStatsSystem(),
        CyberTerminationSystem(),
    )
end

function cyber_model(params::CyberParams = CyberParams())
    world = cyber_world()
    _add_standard_resources!(world, params)
    add_resource!(world, CyberGrid(params.grid_size, params.grid_size))
    add_resource!(world, CyberNetwork(params.grid_size * params.grid_size))
    add_resource!(world, CyberStats())
    scheduler = Scheduler(world, cyber_systems())
    initialize!(scheduler)
    return scheduler
end

struct CyberObserver end

function cyber_headers(::CyberObserver)
    return ["NInfected", "NRecovered", "NSusceptible"]
end

function cyber_values(::CyberObserver, world::World)
    stats = get_resource(world, CyberStats)
    return Float64[stats.n_infected, stats.n_recovered, stats.n_susceptible]
end

function run_cyber(; params::CyberParams = CyberParams(), observe::Bool = true)
    return _run_model(cyber_model, CyberObserver(), cyber_values; params, observe)
end
