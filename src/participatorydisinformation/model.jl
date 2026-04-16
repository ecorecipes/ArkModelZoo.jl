function participatorydisinformation_world(; initial_capacity::Int = 128)
    return World(PDisinfoDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function participatorydisinformation_systems()
    return (InitPDisinfoSystem(), PDisinfoGoSystem(), PDisinfoTerminationSystem())
end

function participatorydisinformation_model(params::PDisinfoParams = PDisinfoParams())
    world = participatorydisinformation_world()
    _add_standard_resources!(world, params)
    add_resource!(world, PDisinfoNetwork())
    add_resource!(world, PDisinfoStats())
    scheduler = Scheduler(world, participatorydisinformation_systems())
    initialize!(scheduler)
    return scheduler
end

struct PDisinfoObserver end

function participatorydisinformation_headers(::PDisinfoObserver)
    return ["EliteHeard", "SocialHeard", "TradedUp", "Created"]
end

function participatorydisinformation_values(::PDisinfoObserver, world::World)
    stats = get_resource(world, PDisinfoStats)
    return Float64[stats.times_heard_from_elites, stats.times_heard_from_social,
                    stats.times_traded_up, stats.times_created_rumor]
end

function run_participatorydisinformation(; params::PDisinfoParams = PDisinfoParams(), observe::Bool = true)
    return _run_model(participatorydisinformation_model, PDisinfoObserver(), participatorydisinformation_values; params, observe)
end
