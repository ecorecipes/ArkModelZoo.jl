function rope_world(; initial_capacity::Int = 128)
    return World(
        RopeDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function rope_systems()
    return (
        InitRopeSystem(),
        RopeUpdateSystem(),
        RopeStatsSystem(),
        RopeTerminationSystem(),
    )
end

function rope_model(params::RopeParams = RopeParams())
    world = rope_world()
    _add_standard_resources!(world, params)
    add_resource!(world, RopeState(params.world_width))
    add_resource!(world, RopeStats())
    scheduler = Scheduler(world, rope_systems())
    initialize!(scheduler)
    return scheduler
end

struct RopeObserver end

function rope_headers(::RopeObserver)
    return ["NVisible"]
end

function rope_values(::RopeObserver, world::World)
    stats = get_resource(world, RopeStats)
    return Float64[stats.n_visible]
end

function run_rope(; params::RopeParams = RopeParams(), observe::Bool = true)
    return _run_model(rope_model, RopeObserver(), rope_values; params, observe)
end
