function minoritygame_world(; initial_capacity::Int = 4096)
    return World(MGAgent; initial_capacity = initial_capacity, allow_mutable = true)
end

function minoritygame_systems()
    return (InitMGSystem(), MGGoSystem(), MGTerminationSystem())
end

function minoritygame_model(params::MGParams = MGParams())
    world = minoritygame_world()
    _add_standard_resources!(world, params)
    add_resource!(world, MGState())
    add_resource!(world, MGStats())
    scheduler = Scheduler(world, minoritygame_systems())
    initialize!(scheduler)
    return scheduler
end

struct MGObserver end

function minoritygame_headers(::MGObserver)
    return ["AvgScore", "StdevScore", "NumPickingZero"]
end

function minoritygame_values(::MGObserver, world::World)
    stats = get_resource(world, MGStats)
    return Float64[stats.avg_score, stats.stdev_score, Float64(stats.num_picking_zero)]
end

function run_minoritygame(; params::MGParams = MGParams(), observe::Bool = true)
    return _run_model(minoritygame_model, MGObserver(), minoritygame_values; params, observe)
end
