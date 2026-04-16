function marriage_world(; initial_capacity::Int = 128)
    return World(MarriageDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function marriage_systems()
    return (
        InitMarriageSystem(),
        MarriageProposeSystem(),
        MarriageRejectSystem(),
        MarriageStatsSystem(),
        MarriageTerminationSystem(),
    )
end

function marriage_model(params::MarriageParams = MarriageParams())
    world = marriage_world()
    _add_standard_resources!(world, params)
    add_resource!(world, MarriageState(params.num_people))
    add_resource!(world, MarriageStats())
    scheduler = Scheduler(world, marriage_systems())
    initialize!(scheduler)
    return scheduler
end

struct MarriageObserver end

function marriage_headers(::MarriageObserver)
    return ["NumBachelors"]
end

function marriage_values(::MarriageObserver, world::World)
    stats = get_resource(world, MarriageStats)
    return Float64[stats.num_bachelors]
end

function run_marriage(; params::MarriageParams = MarriageParams(), observe::Bool = true)
    return _run_model(marriage_model, MarriageObserver(), marriage_values; params, observe)
end
