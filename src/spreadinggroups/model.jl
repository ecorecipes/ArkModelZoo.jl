function spreadinggroups_world(; initial_capacity::Int = 128)
    return World(SGroupDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function spreadinggroups_systems()
    return (InitSGroupSystem(), SGroupGoSystem(), SGroupTerminationSystem())
end

function spreadinggroups_model(params::SGroupParams = SGroupParams())
    world = spreadinggroups_world()
    _add_standard_resources!(world, params)
    add_resource!(world, SGroupNetwork())
    add_resource!(world, SGroupStats())
    scheduler = Scheduler(world, spreadinggroups_systems())
    initialize!(scheduler)
    return scheduler
end

struct SGroupObserver end

function spreadinggroups_headers(::SGroupObserver)
    return ["NumInfected"]
end

function spreadinggroups_values(::SGroupObserver, world::World)
    stats = get_resource(world, SGroupStats)
    return Float64[stats.num_infected]
end

function run_spreadinggroups(; params::SGroupParams = SGroupParams(), observe::Bool = true)
    return _run_model(spreadinggroups_model, SGroupObserver(), spreadinggroups_values; params, observe)
end
