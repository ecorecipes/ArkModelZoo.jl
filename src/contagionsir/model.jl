function contagionsir_world(; initial_capacity::Int = 1024)
    return World(
        CSIRPosition,
        CSIRHeading,
        CSIRState;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function contagionsir_systems()
    return (
        InitContagionSIRSystem(),
        CSIRInfectionRecoverySystem(),
        CSIRMoveSystem(),
        CSIRStatsSystem(),
        CSIRTerminationSystem(),
    )
end

function contagionsir_model(params::ContagionSIRParams = ContagionSIRParams())
    world = contagionsir_world()
    _add_standard_resources!(world, params)
    add_resource!(world, CSIRStats())
    scheduler = Scheduler(world, contagionsir_systems())
    initialize!(scheduler)
    return scheduler
end

struct ContagionSIRObserver end

function contagionsir_headers(::ContagionSIRObserver)
    return ["NInfected", "NImmune"]
end

function contagionsir_values(::ContagionSIRObserver, world::World)
    stats = get_resource(world, CSIRStats)
    return Float64[stats.n_infected, stats.n_immune]
end

function run_contagionsir(; params::ContagionSIRParams = ContagionSIRParams(), observe::Bool = true)
    return _run_model(contagionsir_model, ContagionSIRObserver(), contagionsir_values; params, observe)
end
