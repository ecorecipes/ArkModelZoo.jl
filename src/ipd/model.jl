function ipd_world(; initial_capacity::Int = 128)
    return World(IPDDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function ipd_systems()
    return (
        InitIPDSystem(),
        IPDPlaySystem(),
        IPDEvolveSystem(),
        IPDStatsSystem(),
        IPDTerminationSystem(),
    )
end

function ipd_model(params::IPDParams = IPDParams())
    world = ipd_world()
    _add_standard_resources!(world, params)
    add_resource!(world, IPDGrid(params.grid_size, params.grid_size))
    add_resource!(world, IPDStats())
    scheduler = Scheduler(world, ipd_systems())
    initialize!(scheduler)
    return scheduler
end

struct IPDObserver end

function ipd_headers(::IPDObserver)
    return ["MeanScore"]
end

function ipd_values(::IPDObserver, world::World)
    stats = get_resource(world, IPDStats)
    return Float64[stats.mean_score]
end

function run_ipd(; params::IPDParams = IPDParams(), observe::Bool = true)
    return _run_model(ipd_model, IPDObserver(), ipd_values; params, observe)
end
