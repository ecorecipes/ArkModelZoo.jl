function contagionnw_world(; initial_capacity::Int = 128)
    return World(CNWDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function contagionnw_systems()
    return (InitContagionNWSystem(), CNWSpreadSystem(), CNWTerminationSystem())
end

function contagionnw_model(params::ContagionNWParams = ContagionNWParams())
    world = contagionnw_world()
    _add_standard_resources!(world, params)
    add_resource!(world, CNWNetwork())
    add_resource!(world, CNWStats())
    scheduler = Scheduler(world, contagionnw_systems())
    initialize!(scheduler)
    return scheduler
end

struct ContagionNWObserver end

function contagionnw_headers(::ContagionNWObserver)
    return ["NumInfectedNW", "NumLinksNW"]
end

function contagionnw_values(::ContagionNWObserver, world::World)
    stats = get_resource(world, CNWStats)
    return Float64[stats.num_infected, stats.num_links]
end

function run_contagionnw(; params::ContagionNWParams = ContagionNWParams(), observe::Bool = true)
    return _run_model(contagionnw_model, ContagionNWObserver(), contagionnw_values; params, observe)
end
