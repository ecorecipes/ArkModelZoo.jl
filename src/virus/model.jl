function virus_world(; initial_capacity::Int = 512)
    return World(
        VPosition,
        VHeading,
        VirusState,
        VirusTimer;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function virus_systems()
    return (
        InitVirusSystem(),
        VirusSpreadSystem(),
        VirusResistanceSystem(),
        VirusStatsSystem(),
        VirusTerminationSystem(),
    )
end

function virus_model(params::VirusParams = VirusParams())
    world = virus_world()
    _add_standard_resources!(world, params)
    add_resource!(world, VirusStats())
    add_resource!(world, VirusNetwork())
    scheduler = Scheduler(world, virus_systems())
    initialize!(scheduler)
    return scheduler
end

struct VirusObserver end

function virus_headers(::VirusObserver)
    return ["NumSusceptible", "NumInfected", "NumResistant"]
end

function virus_values(::VirusObserver, world::World)
    stats = get_resource(world, VirusStats)
    return Float64[stats.num_susceptible, stats.num_infected, stats.num_resistant]
end

function run_virus(; params::VirusParams = VirusParams(), observe::Bool = true)
    return _run_model(virus_model, VirusObserver(), virus_values; params, observe)
end
