function slowspread_world(; initial_capacity::Int = 128)
    return World(SSpreadDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function slowspread_systems()
    return (InitSSpreadSystem(), SSpreadGoSystem(), SSpreadTerminationSystem())
end

function slowspread_model(params::SSpreadParams = SSpreadParams())
    world = slowspread_world()
    _add_standard_resources!(world, params)
    add_resource!(world, SSpreadNetwork())
    add_resource!(world, SSpreadStats())
    scheduler = Scheduler(world, slowspread_systems())
    initialize!(scheduler)
    return scheduler
end

struct SSpreadObserver end

function slowspread_headers(::SSpreadObserver)
    return ["PctGreen", "PctGrey"]
end

function slowspread_values(::SSpreadObserver, world::World)
    stats = get_resource(world, SSpreadStats)
    return Float64[stats.pct_green, stats.pct_grey]
end

function run_slowspread(; params::SSpreadParams = SSpreadParams(), observe::Bool = true)
    return _run_model(slowspread_model, SSpreadObserver(), slowspread_values; params, observe)
end
