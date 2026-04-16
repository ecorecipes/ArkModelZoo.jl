function socialinfluence_world(; initial_capacity::Int = 128)
    return World(SInflDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function socialinfluence_systems()
    return (InitSInflSystem(), SInflGoSystem(), SInflTerminationSystem())
end

function socialinfluence_model(params::SInflParams = SInflParams())
    world = socialinfluence_world()
    _add_standard_resources!(world, params)
    add_resource!(world, SInflState())
    add_resource!(world, SInflStats())
    scheduler = Scheduler(world, socialinfluence_systems())
    initialize!(scheduler)
    return scheduler
end

struct SInflObserver end

function socialinfluence_headers(::SInflObserver)
    return ["NumberInfluence"]
end

function socialinfluence_values(::SInflObserver, world::World)
    stats = get_resource(world, SInflStats)
    return Float64[stats.number_influence]
end

function run_socialinfluence(; params::SInflParams = SInflParams(), observe::Bool = true)
    return _run_model(socialinfluence_model, SInflObserver(), socialinfluence_values; params, observe)
end
