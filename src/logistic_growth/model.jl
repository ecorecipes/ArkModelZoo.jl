function lg_world(; initial_capacity::Int = 64)
    return World(; initial_capacity = initial_capacity, allow_mutable = true)
end

function lg_systems()
    return (
        InitLGSystem(),
        LGGoSystem(),
        LGTerminationSystem(),
    )
end

function lg_model(params::LGParams = LGParams())
    world = lg_world()
    _add_standard_resources!(world, params)
    add_resource!(world, LGState())
    scheduler = Scheduler(world, lg_systems())
    initialize!(scheduler)
    return scheduler
end

struct LGObserver end

function lg_headers(::LGObserver)
    return ["Stock"]
end

function lg_values(::LGObserver, world::World)
    state = get_resource(world, LGState)
    return Float64[state.stock]
end

function run_logistic_growth(; params::LGParams = LGParams(), observe::Bool = true)
    return _run_model(lg_model, LGObserver(), lg_values; params, observe)
end
