function bullwhip_world(; initial_capacity::Int = 128)
    return World(BullwhipDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function bullwhip_systems()
    return (
        InitBullwhipSystem(),
        BullwhipStepSystem(),
        BullwhipStatsSystem(),
        BullwhipTerminationSystem(),
    )
end

function bullwhip_model(params::BullwhipParams = BullwhipParams())
    world = bullwhip_world()
    _add_standard_resources!(world, params)
    add_resource!(world, BullwhipState())
    add_resource!(world, BullwhipStats())
    scheduler = Scheduler(world, bullwhip_systems())
    initialize!(scheduler)
    return scheduler
end

struct BullwhipObserver end

function bullwhip_headers(::BullwhipObserver)
    return ["NCustomers", "R1Stock", "R2Stock", "WStock"]
end

function bullwhip_values(::BullwhipObserver, world::World)
    stats = get_resource(world, BullwhipStats)
    return Float64[stats.n_customers, stats.r1_stock, stats.r2_stock, stats.w_stock]
end

function run_bullwhip(; params::BullwhipParams = BullwhipParams(), observe::Bool = true)
    return _run_model(bullwhip_model, BullwhipObserver(), bullwhip_values; params, observe)
end
