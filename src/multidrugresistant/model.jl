function multidrugresistant_world(; initial_capacity::Int = 256)
    return World(
        MDRPosition,
        MDRHeading,
        PatientTag,
        NurseTag,
        CleanerTag,
        MDRInfection;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function multidrugresistant_systems()
    return (
        InitMDRSystem(),
        MDRInfectionSystem(),
        MDRPatientSystem(),
        MDRMoveSystem(),
        MDRTerminationSystem(),
    )
end

function multidrugresistant_model(params::MDRParams = MDRParams())
    world = multidrugresistant_world()
    _add_standard_resources!(world, params)
    add_resource!(world, MDRGrid(205, 129))
    add_resource!(world, MDRStats())
    scheduler = Scheduler(world, multidrugresistant_systems())
    initialize!(scheduler)
    return scheduler
end

struct MDRObserver end

function multidrugresistant_headers(::MDRObserver)
    return ["DeadPatients", "RecoveredPatients"]
end

function multidrugresistant_values(::MDRObserver, world::World)
    stats = get_resource(world, MDRStats)
    return Float64[Float64(stats.dead_patients), Float64(stats.recovered_patients)]
end

function run_multidrugresistant(; params::MDRParams = MDRParams(), observe::Bool = true)
    return _run_model(multidrugresistant_model, MDRObserver(), multidrugresistant_values; params, observe)
end
