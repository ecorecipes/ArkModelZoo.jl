function wisdomcrowd_world(; initial_capacity::Int = 1024)
    return World(WCDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function wisdomcrowd_systems()
    return (
        InitWCSystem(),
        WCGoSystem(),
        WCTerminationSystem(),
    )
end

function wisdomcrowd_model(params::WCParams = WCParams())
    world = wisdomcrowd_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, WCState())
    add_resource!(world, WCStats())
    scheduler = Scheduler(world, wisdomcrowd_systems())
    initialize!(scheduler)
    return scheduler
end

struct WisdomCrowdObserver end

function wisdomcrowd_headers(::WisdomCrowdObserver)
    return ["cnt_offenders", "cnt_inter", "cnt_neutralized", "curr_oi"]
end

function wisdomcrowd_values(::WisdomCrowdObserver, world::World)
    stats = get_resource(world, WCStats)
    return Float64[stats.cnt_offenders, stats.cnt_inter, stats.cnt_neutralized, stats.curr_oi]
end

function run_wisdomcrowd(; params::WCParams = WCParams(), observe::Bool = true)
    scheduler = wisdomcrowd_model(params)
    obs = WisdomCrowdObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, wisdomcrowd_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, wisdomcrowd_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
