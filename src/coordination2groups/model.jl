function coordination2groups_world(; initial_capacity::Int = 2048)
    return World(
        Coord2GroupID,
        Coord2Norm1,
        Coord2Payoff;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function coordination2groups_systems()
    return (
        InitCoordination2GroupsSystem(),
        Coord2CalculatePayoffsSystem(),
        Coord2EvolveSystem(),
        Coordination2GroupsTerminationSystem(),
    )
end

function coordination2groups_model(params::Coordination2GroupsParams = Coordination2GroupsParams())
    world = coordination2groups_world()
    _add_standard_resources!(world, params)
    add_resource!(world, Coordination2GroupsStats())
    scheduler = Scheduler(world, coordination2groups_systems())
    initialize!(scheduler)
    return scheduler
end

struct Coordination2GroupsObserver end

function coordination2groups_headers(::Coordination2GroupsObserver)
    return ["NNorm1"]
end

function coordination2groups_values(::Coordination2GroupsObserver, world::World)
    stats = get_resource(world, Coordination2GroupsStats)
    return Float64[stats.n_norm1]
end

function run_coordination2groups(; params::Coordination2GroupsParams = Coordination2GroupsParams(), observe::Bool = true)
    return _run_model(coordination2groups_model, Coordination2GroupsObserver(), coordination2groups_values; params, observe)
end
