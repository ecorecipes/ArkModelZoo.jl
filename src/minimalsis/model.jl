function minimalsis_world(; initial_capacity::Int = 64)
    return World(MSISDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function minimalsis_systems()
    return (InitMSISSystem(), MSISGoSystem(), MSISTerminationSystem())
end

function minimalsis_model(params::MinimalSISParams = MinimalSISParams())
    world = minimalsis_world()
    _add_standard_resources!(world, params)
    add_resource!(world, MSISState())
    add_resource!(world, MSISStats())
    scheduler = Scheduler(world, minimalsis_systems())
    initialize!(scheduler)
    return scheduler
end

struct MSISObserver end

function minimalsis_headers(::MSISObserver)
    return ["ReproductionNumber", "NewInfected"]
end

function minimalsis_values(::MSISObserver, world::World)
    stats = get_resource(world, MSISStats)
    return Float64[stats.reproduction_number, stats.new_infected]
end

function run_minimalsis(; params::MinimalSISParams = MinimalSISParams(), observe::Bool = true)
    return _run_model(minimalsis_model, MSISObserver(), minimalsis_values; params, observe)
end
