function altruism_world(; initial_capacity::Int = 128)
    return World(ALTDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function altruism_systems()
    return (
        InitALTSystem(),
        ALTGoSystem(),
        ALTTerminationSystem(),
    )
end

function altruism_model(params::ALTParams = ALTParams())
    world = altruism_world()
    _add_standard_resources!(world, params)
    add_resource!(world, ALTGrid(params.grid_width, params.grid_height))
    add_resource!(world, ALTStats())
    scheduler = Scheduler(world, altruism_systems())
    initialize!(scheduler)
    return scheduler
end

struct ALTObserver end

function altruism_headers(::ALTObserver)
    return ["NumAltruists", "NumSelfish", "NumHarsh"]
end

function altruism_values(::ALTObserver, world::World)
    stats = get_resource(world, ALTStats)
    return Float64[stats.num_altruists, stats.num_selfish, stats.num_harsh]
end

function run_altruism(; params::ALTParams = ALTParams(), observe::Bool = true)
    return _run_model(altruism_model, ALTObserver(), altruism_values; params, observe)
end
