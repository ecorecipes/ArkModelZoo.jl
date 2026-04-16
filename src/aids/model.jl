function aids_world(; initial_capacity::Int = 1024)
    return World(AIDSPerson; initial_capacity = initial_capacity, allow_mutable = true)
end

function aids_systems()
    return (InitAIDSSystem(), AIDSGoSystem(), AIDSTerminationSystem())
end

function aids_model(params::AIDSParams = AIDSParams())
    world = aids_world()
    _add_standard_resources!(world, params)
    add_resource!(world, AIDSStats())
    scheduler = Scheduler(world, aids_systems())
    initialize!(scheduler)
    return scheduler
end

struct AIDSObserver end

function aids_headers(::AIDSObserver)
    return ["Uninfected", "InfectedUnknown", "InfectedKnown", "PctInfected"]
end

function aids_values(::AIDSObserver, world::World)
    stats = get_resource(world, AIDSStats)
    return Float64[stats.num_uninfected, stats.num_infected_unknown,
                    stats.num_infected_known, stats.pct_infected]
end

function run_aids(; params::AIDSParams = AIDSParams(), observe::Bool = true)
    return _run_model(aids_model, AIDSObserver(), aids_values; params, observe)
end
