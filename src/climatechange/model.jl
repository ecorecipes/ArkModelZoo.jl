function climatechange_world(; initial_capacity::Int = 1024)
    return World(
        ClimateParticle;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function climatechange_systems()
    return (
        InitClimateChangeSystem(),
        RunSunshineSystem(),
        RunHeatSystem(),
        RunIRSystem(),
        RunCO2System(),
        ClimateChangeTerminationSystem(),
    )
end

function climatechange_model(params::ClimateChangeParams = ClimateChangeParams())
    world = climatechange_world()
    _add_standard_resources!(world, params)
    add_resource!(world, ClimateStats())
    scheduler = Scheduler(world, climatechange_systems())
    initialize!(scheduler)
    return scheduler
end

struct ClimateChangeObserver end

function climatechange_headers(::ClimateChangeObserver)
    return ["Temperature"]
end

function climatechange_values(::ClimateChangeObserver, world::World)
    stats = get_resource(world, ClimateStats)
    return Float64[stats.temperature]
end

function run_climatechange(; params::ClimateChangeParams = ClimateChangeParams(), observe::Bool = true)
    return _run_model(climatechange_model, ClimateChangeObserver(), climatechange_values; params, observe)
end
