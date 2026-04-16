function thermostat_world(; initial_capacity::Int = 4096)
    return World(
        ThermoPosition,
        ThermoHeading;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function thermostat_systems()
    return (
        InitThermoSystem(),
        ThermoCirculateSystem(),
        ThermoTemperatureSystem(),
        ThermoHeaterSystem(),
        ThermoStatsSystem(),
        ThermoTerminationSystem(),
    )
end

function thermostat_model(params::ThermostatParams = ThermostatParams())
    world = thermostat_world()
    _add_standard_resources!(world, params)
    add_resource!(world, ThermoGrid(params.grid_width, params.grid_height, params.min_cor))
    add_resource!(world, ThermoStats())
    scheduler = Scheduler(world, thermostat_systems())
    initialize!(scheduler)
    return scheduler
end

struct ThermostatObserver end

function thermostat_headers(::ThermostatObserver)
    return ["Temperature"]
end

function thermostat_values(::ThermostatObserver, world::World)
    stats = get_resource(world, ThermoStats)
    return Float64[stats.temperature]
end

function run_thermostat(; params::ThermostatParams = ThermostatParams(), observe::Bool = true)
    return _run_model(thermostat_model, ThermostatObserver(), thermostat_values; params, observe)
end
