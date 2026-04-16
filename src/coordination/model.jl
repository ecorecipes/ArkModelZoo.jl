function coordination_world(; initial_capacity::Int = 2048)
    return World(
        CoordPosition,
        CoordNorm,
        CoordPayoff;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function coordination_systems()
    return (
        InitCoordSystem(),
        CalcPayoffsSystem(),
        EvolveSystem(),
        CoordStatsSystem(),
        CoordTerminationSystem(),
    )
end

function coordination_model(params::CoordinationParams = CoordinationParams())
    world = coordination_world()
    _add_standard_resources!(world, params)
    add_resource!(world, CoordStats())
    scheduler = Scheduler(world, coordination_systems())
    initialize!(scheduler)
    return scheduler
end

struct CoordinationObserver end

function coordination_headers(::CoordinationObserver)
    return ["NNorm1"]
end

function coordination_values(::CoordinationObserver, world::World)
    stats = get_resource(world, CoordStats)
    return Float64[stats.n_norm1]
end

function run_coordination(; params::CoordinationParams = CoordinationParams(), observe::Bool = true)
    return _run_model(coordination_model, CoordinationObserver(), coordination_values; params, observe)
end
