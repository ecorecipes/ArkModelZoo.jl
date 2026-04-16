function disinfobitstringnw_world(; initial_capacity::Int = 128)
    return World(DisBitDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function disinfobitstringnw_systems()
    return (InitDisBitSystem(), DisBitGoSystem(), DisBitTerminationSystem())
end

function disinfobitstringnw_model(params::DisBitParams = DisBitParams())
    world = disinfobitstringnw_world()
    _add_standard_resources!(world, params)
    add_resource!(world, DisBitNetwork())
    add_resource!(world, DisBitStats())
    scheduler = Scheduler(world, disinfobitstringnw_systems())
    initialize!(scheduler)
    return scheduler
end

struct DisBitObserver end

function disinfobitstringnw_headers(::DisBitObserver)
    return ["EliteHeard", "SocialHeard", "TradedUp", "Created"]
end

function disinfobitstringnw_values(::DisBitObserver, world::World)
    stats = get_resource(world, DisBitStats)
    return Float64[stats.times_heard_from_elites, stats.times_heard_from_social,
                    stats.times_traded_up, stats.times_created_rumor]
end

function run_disinfobitstringnw(; params::DisBitParams = DisBitParams(), observe::Bool = true)
    return _run_model(disinfobitstringnw_model, DisBitObserver(), disinfobitstringnw_values; params, observe)
end
