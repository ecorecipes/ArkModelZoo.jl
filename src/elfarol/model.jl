function elfarol_world(; initial_capacity::Int = 256)
    return World(
        ElFarolStrategies,
        ElFarolDecision;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function elfarol_systems()
    return (
        InitElFarolSystem(),
        ElFarolUpdateSystem(),
        ElFarolStatsSystem(),
        ElFarolTerminationSystem(),
    )
end

function elfarol_model(params::ElFarolParams = ElFarolParams())
    world = elfarol_world()
    _add_standard_resources!(world, params)
    add_resource!(world, ElFarolHistory(params.memory_size * 2))
    add_resource!(world, ElFarolStats())
    scheduler = Scheduler(world, elfarol_systems())
    initialize!(scheduler)
    return scheduler
end

struct ElFarolObserver end

function elfarol_headers(::ElFarolObserver)
    return ["Attendance"]
end

function elfarol_values(::ElFarolObserver, world::World)
    stats = get_resource(world, ElFarolStats)
    return Float64[stats.attendance]
end

function run_elfarol(; params::ElFarolParams = ElFarolParams(), observe::Bool = true)
    return _run_model(elfarol_model, ElFarolObserver(), elfarol_values; params, observe)
end
