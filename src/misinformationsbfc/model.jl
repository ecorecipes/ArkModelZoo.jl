function misinformationsbfc_world(; initial_capacity::Int = 128)
    return World(MisSBFCDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function misinformationsbfc_systems()
    return (InitMisSBFCSystem(), MisSBFCGoSystem(), MisSBFCTerminationSystem())
end

function misinformationsbfc_model(params::MisSBFCParams = MisSBFCParams())
    world = misinformationsbfc_world()
    _add_standard_resources!(world, params)
    add_resource!(world, MisSBFCNetwork())
    add_resource!(world, MisSBFCStats())
    scheduler = Scheduler(world, misinformationsbfc_systems())
    initialize!(scheduler)
    return scheduler
end

struct MisSBFCObserver end

function misinformationsbfc_headers(::MisSBFCObserver)
    return ["NumBelievers", "NumFactcheckers", "NumSusceptibles"]
end

function misinformationsbfc_values(::MisSBFCObserver, world::World)
    stats = get_resource(world, MisSBFCStats)
    return Float64[stats.num_believers, stats.num_factcheckers, stats.num_susceptibles]
end

function run_misinformationsbfc(; params::MisSBFCParams = MisSBFCParams(), observe::Bool = true)
    return _run_model(misinformationsbfc_model, MisSBFCObserver(), misinformationsbfc_values; params, observe)
end
