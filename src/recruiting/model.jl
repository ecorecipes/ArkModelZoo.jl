function recruiting_world(; initial_capacity::Int = 128)
    return World(RecDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function recruiting_systems()
    return (
        InitRecSystem(),
        RecGoSystem(),
        RecTerminationSystem(),
    )
end

function recruiting_model(params::RecParams = RecParams())
    world = recruiting_world()
    _add_standard_resources!(world, params)
    add_resource!(world, RecState())
    add_resource!(world, RecStats())
    scheduler = Scheduler(world, recruiting_systems())
    initialize!(scheduler)
    return scheduler
end

struct RecruitingObserver end

function recruiting_headers(::RecruitingObserver)
    return ["recruitpct", "resistpct", "neutralpct"]
end

function recruiting_values(::RecruitingObserver, world::World)
    stats = get_resource(world, RecStats)
    return Float64[stats.recruitpct, stats.resistpct, stats.neutralpct]
end

function run_recruiting(; params::RecParams = RecParams(), observe::Bool = true)
    return _run_model(recruiting_model, RecruitingObserver(), recruiting_values; params, observe)
end
