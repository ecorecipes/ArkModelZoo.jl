function leonarditechadoption_world(; initial_capacity::Int = 128)
    return World(LTechDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function leonarditechadoption_systems()
    return (
        InitLTechSystem(),
        LTechGoSystem(),
        LTechTerminationSystem(),
    )
end

function leonarditechadoption_model(params::LTechParams = LTechParams())
    world = leonarditechadoption_world()
    _add_standard_resources!(world, params)
    add_resource!(world, LTechState())
    add_resource!(world, LTechStats())
    scheduler = Scheduler(world, leonarditechadoption_systems())
    initialize!(scheduler)
    return scheduler
end

struct LTechObserver end

function leonarditechadoption_headers(::LTechObserver)
    return ["n_users", "n_active"]
end

function leonarditechadoption_values(::LTechObserver, world::World)
    stats = get_resource(world, LTechStats)
    return Float64[stats.n_users, stats.n_active]
end

function run_leonarditechadoption(; params::LTechParams = LTechParams(), observe::Bool = true)
    return _run_model(leonarditechadoption_model, LTechObserver(), leonarditechadoption_values; params, observe)
end
