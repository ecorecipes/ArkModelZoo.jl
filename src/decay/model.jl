function decay_world(; initial_capacity::Int = 4096)
    return World(
        NucleusPosition,
        ActiveNucleus,
        JustDecayed,
        DecayedNucleus;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function decay_systems()
    return (
        InitDecaySystem(),
        DecaySystem(),
        DecayStatsSystem(),
        DecayTerminationSystem(),
    )
end

function decay_model(params::DecayParams = DecayParams())
    world = decay_world()
    _add_standard_resources!(world, params)
    add_resource!(world, DecayStats())
    scheduler = Scheduler(world, decay_systems())
    initialize!(scheduler)
    return scheduler
end

struct DecayObserver end

function decay_headers(::DecayObserver)
    return ["Decays"]
end

function decay_values(::DecayObserver, world::World)
    stats = get_resource(world, DecayStats)
    return Float64[stats.decays]
end

function run_decay(; params::DecayParams = DecayParams(), observe::Bool = true)
    return _run_model(decay_model, DecayObserver(), decay_values; params, observe)
end
