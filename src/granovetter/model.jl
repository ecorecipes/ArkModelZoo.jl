function gran_world(; initial_capacity::Int = 256)
    return World(GRANAgent; initial_capacity = initial_capacity, allow_mutable = true)
end

function gran_systems()
    return (
        InitGRANSystem(),
        GRANGoSystem(),
        GRANTerminationSystem(),
    )
end

function gran_model(params::GRANParams = GRANParams())
    world = gran_world()
    _add_standard_resources!(world, params)
    add_resource!(world, GRANNetwork(params.number_of_agents))
    add_resource!(world, GRANStats())
    scheduler = Scheduler(world, gran_systems())
    initialize!(scheduler)
    return scheduler
end

struct GRANObserver end

function gran_headers(::GRANObserver)
    return ["PercentRioting", "NumRioting"]
end

function gran_values(::GRANObserver, world::World)
    stats = get_resource(world, GRANStats)
    return Float64[stats.percent_rioting, Float64(stats.num_rioting)]
end

function run_granovetter(; params::GRANParams = GRANParams(), observe::Bool = true)
    return _run_model(gran_model, GRANObserver(), gran_values; params, observe)
end
