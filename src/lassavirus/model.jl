function lassavirus_world(; initial_capacity::Int = 1024)
    return World(
        LassaPosition,
        LassaHeading,
        HumanState,
        RatTag;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function lassavirus_systems()
    return (
        InitLassaSystem(),
        LassaMovementSystem(),
        LassaInfectionSystem(),
        LassaStatsSystem(),
        LassaTerminationSystem(),
    )
end

function lassavirus_model(params::LassaParams = LassaParams())
    world = lassavirus_world()
    _add_standard_resources!(world, params)
    add_resource!(world, LassaStats())
    add_resource!(world, LassaRegistry())
    scheduler = Scheduler(world, lassavirus_systems())
    initialize!(scheduler)
    return scheduler
end

struct LassaVirusObserver end

function lassavirus_headers(::LassaVirusObserver)
    return ["PctInfected", "PctImmune", "CurrentCases", "TotalFatalities"]
end

function lassavirus_values(::LassaVirusObserver, world::World)
    stats = get_resource(world, LassaStats)
    return Float64[stats.pct_infected, stats.pct_immune, Float64(stats.current_cases), Float64(stats.total_fatalities)]
end

function run_lassavirus(; params::LassaParams = LassaParams(), observe::Bool = true)
    return _run_model(lassavirus_model, LassaVirusObserver(), lassavirus_values; params, observe)
end
