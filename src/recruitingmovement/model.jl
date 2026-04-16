function recruitingmovement_world(; initial_capacity::Int = 128)
    return World(RecMovDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function recruitingmovement_systems()
    return (
        InitRecMovSystem(),
        RecMovGoSystem(),
        RecMovTerminationSystem(),
    )
end

function recruitingmovement_model(params::RecMovParams = RecMovParams())
    world = recruitingmovement_world()
    _add_standard_resources!(world, params)
    add_resource!(world, RecMovState())
    add_resource!(world, RecMovStats())
    scheduler = Scheduler(world, recruitingmovement_systems())
    initialize!(scheduler)
    return scheduler
end

struct RecMovObserver end

function recruitingmovement_headers(::RecMovObserver)
    return ["recruitpct", "resistpct", "neutralpct"]
end

function recruitingmovement_values(::RecMovObserver, world::World)
    stats = get_resource(world, RecMovStats)
    return Float64[stats.recruitpct, stats.resistpct, stats.neutralpct]
end

function run_recruitingmovement(; params::RecMovParams = RecMovParams(), observe::Bool = true)
    return _run_model(recruitingmovement_model, RecMovObserver(), recruitingmovement_values; params, observe)
end
