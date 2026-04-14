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
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = bullwhip_model(params)
    obs = BullwhipObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, bullwhip_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, bullwhip_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
