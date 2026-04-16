function sir_world(; initial_capacity::Int = 1024)
    return World(
        SIRPosition,
        SIRHeading,
        DaysInfected,
        SIRSusceptible,
        SIRInfected,
        SIRRecovered;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function sir_systems()
    return (
        InitSIRSystem(),
        SIRMovementSystem(),
        SIRInfectionSystem(),
        SIRStatsSystem(),
        SIRTerminationSystem(),
    )
end

function sir_model(params::SIRParams = SIRParams())
    world = sir_world()
    _add_standard_resources!(world, params)
    add_resource!(world, SIRStats())
    scheduler = Scheduler(world, sir_systems())
    initialize!(scheduler)
    return scheduler
end

struct SIRObserver end

function sir_headers(::SIRObserver)
    return ["NumSusceptible", "NumInfected", "NumRecovered"]
end

function sir_values(::SIRObserver, world::World)
    stats = get_resource(world, SIRStats)
    return Float64[stats.num_susceptible, stats.num_infected, stats.num_recovered]
end

function run_sir(; params::SIRParams = SIRParams(), observe::Bool = true)
    return _run_model(sir_model, SIRObserver(), sir_values; params, observe)
end
