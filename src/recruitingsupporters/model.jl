function recruitingsupporters_world(; initial_capacity::Int = 128)
    return World(RecSupDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function recruitingsupporters_systems()
    return (
        InitRecSupSystem(),
        RecSupGoSystem(),
        RecSupTerminationSystem(),
    )
end

function recruitingsupporters_model(params::RecSupParams = RecSupParams())
    world = recruitingsupporters_world()
    _add_standard_resources!(world, params)
    add_resource!(world, RecSupState())
    add_resource!(world, RecSupStats())
    scheduler = Scheduler(world, recruitingsupporters_systems())
    initialize!(scheduler)
    return scheduler
end

struct RecSupObserver end

function recruitingsupporters_headers(::RecSupObserver)
    return ["recruitpct", "resistpct", "neutralpct"]
end

function recruitingsupporters_values(::RecSupObserver, world::World)
    stats = get_resource(world, RecSupStats)
    return Float64[stats.recruitpct, stats.resistpct, stats.neutralpct]
end

function run_recruitingsupporters(; params::RecSupParams = RecSupParams(), observe::Bool = true)
    return _run_model(recruitingsupporters_model, RecSupObserver(), recruitingsupporters_values; params, observe)
end
