function babysittingcoop_world(; initial_capacity::Int = 128)
    return World(BSitDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function babysittingcoop_systems()
    return (
        InitBSitSystem(),
        BSitGoSystem(),
        BSitTerminationSystem(),
    )
end

function babysittingcoop_model(params::BSitParams = BSitParams())
    world = babysittingcoop_world()
    _add_standard_resources!(world, params)
    add_resource!(world, BSitState())
    add_resource!(world, BSitStats())
    scheduler = Scheduler(world, babysittingcoop_systems())
    initialize!(scheduler)
    return scheduler
end

struct BabysittingCoopObserver end

function babysittingcoop_headers(::BabysittingCoopObserver)
    return ["total_scrip", "going_out_count", "sitting_count"]
end

function babysittingcoop_values(::BabysittingCoopObserver, world::World)
    stats = get_resource(world, BSitStats)
    return Float64[stats.total_scrip, stats.going_out_count, stats.sitting_count]
end

function run_babysittingcoop(; params::BSitParams = BSitParams(), observe::Bool = true)
    return _run_model(babysittingcoop_model, BabysittingCoopObserver(), babysittingcoop_values; params, observe)
end
