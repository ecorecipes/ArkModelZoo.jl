function mimicry_world(; initial_capacity::Int = 2048)
    return World(
        MimicryPosition,
        MimicryHeading,
        MimicryColor,
        BirdMemory,
        MonarchTag,
        ViceroyTag,
        BirdTag;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function mimicry_systems()
    return (
        InitMimicrySystem(),
        MimicryBirdMoveSystem(),
        MimicryButterflyMoveSystem(),
        MimicryEatingSystem(),
        MimicryForgetSystem(),
        MimicryReproductionSystem(),
        MimicryStatsSystem(),
        MimicryTerminationSystem(),
    )
end

function mimicry_model(params::MimicryParams = MimicryParams())
    world = mimicry_world()
    _add_standard_resources!(world, params)
    add_resource!(world, MimicryStats())
    scheduler = Scheduler(world, mimicry_systems())
    initialize!(scheduler)
    return scheduler
end

struct MimicryObserver end

function mimicry_headers(::MimicryObserver)
    return ["Monarchs", "Viceroys", "Birds"]
end

function mimicry_values(::MimicryObserver, world::World)
    stats = get_resource(world, MimicryStats)
    return Float64[stats.n_monarchs, stats.n_viceroys, stats.n_birds]
end

function run_mimicry(; params::MimicryParams = MimicryParams(), observe::Bool = true)
    return _run_model(mimicry_model, MimicryObserver(), mimicry_values; params, observe)
end
