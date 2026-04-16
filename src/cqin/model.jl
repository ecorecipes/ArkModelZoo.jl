function cqin_world(; initial_capacity::Int = 128)
    return World(CQINDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function cqin_systems()
    return (InitCQINSystem(), CQINGoSystem(), CQINTerminationSystem())
end

function cqin_model(params::CQINParams = CQINParams())
    world = cqin_world()
    _add_standard_resources!(world, params)
    add_resource!(world, CQINNetwork())
    add_resource!(world, CQINStats())
    scheduler = Scheduler(world, cqin_systems())
    initialize!(scheduler)
    return scheduler
end

struct CQINObserver end

function cqin_headers(::CQINObserver)
    return ["NumUpdated", "NumResistant", "NumAdjusted"]
end

function cqin_values(::CQINObserver, world::World)
    stats = get_resource(world, CQINStats)
    return Float64[stats.num_updated, stats.num_resistant, stats.num_adjusted]
end

function run_cqin(; params::CQINParams = CQINParams(), observe::Bool = true)
    return _run_model(cqin_model, CQINObserver(), cqin_values; params, observe)
end
