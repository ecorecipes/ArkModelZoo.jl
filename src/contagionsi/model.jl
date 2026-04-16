function contagionsi_world(; initial_capacity::Int = 1024)
    return World(
        CIPosition,
        CIHeading,
        CISusceptible,
        CIInfected;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function contagionsi_systems()
    return (
        InitContagionSISystem(),
        CIInfectionSystem(),
        CIMovementSystem(),
        CIStatsSystem(),
        CITerminationSystem(),
    )
end

function contagionsi_model(params::ContagionSIParams = ContagionSIParams())
    world = contagionsi_world()
    _add_standard_resources!(world, params)
    add_resource!(world, CIStats())
    scheduler = Scheduler(world, contagionsi_systems())
    initialize!(scheduler)
    return scheduler
end

struct ContagionSIObserver end

function contagionsi_headers(::ContagionSIObserver)
    return ["NInfected"]
end

function contagionsi_values(::ContagionSIObserver, world::World)
    stats = get_resource(world, CIStats)
    return Float64[stats.n_infected]
end

function run_contagionsi(; params::ContagionSIParams = ContagionSIParams(), observe::Bool = true)
    return _run_model(contagionsi_model, ContagionSIObserver(), contagionsi_values; params, observe)
end
