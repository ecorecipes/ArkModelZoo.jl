function daisyworld_world(; initial_capacity::Int = 2048)
    return World(
        DaisyPosition,
        DaisyAge,
        Albedo,
        WhiteDaisy,
        BlackDaisy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function daisyworld_systems()
    return (
        InitDaisyworldSystem(),
        CalcTemperatureSystem(),
        DiffuseTemperatureSystem(),
        SurvivabilitySystem(),
        DaisyStatsSystem(),
        DaisyworldTerminationSystem(),
    )
end

function daisyworld_model(params::DaisyworldParams = DaisyworldParams())
    world = daisyworld_world()
    _add_standard_resources!(world, params)
    add_resource!(world, TemperatureGrid(params.grid_size, params.grid_size))
    add_resource!(world, DaisyStats())
    scheduler = Scheduler(world, daisyworld_systems())
    initialize!(scheduler)
    return scheduler
end

struct DaisyworldObserver end

function daisyworld_headers(::DaisyworldObserver)
    return ["GlobalTemp", "NumWhites", "NumBlacks", "SolarLuminosity"]
end

function daisyworld_values(::DaisyworldObserver, world::World)
    stats = get_resource(world, DaisyStats)
    return Float64[stats.global_temperature, stats.num_whites,
                    stats.num_blacks, stats.solar_luminosity]
end

function run_daisyworld(; params::DaisyworldParams = DaisyworldParams(), observe::Bool = true)
    return _run_model(daisyworld_model, DaisyworldObserver(), daisyworld_values; params, observe)
end
