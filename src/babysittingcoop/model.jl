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
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = babysittingcoop_model(params)
    obs = BabysittingCoopObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, babysittingcoop_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, babysittingcoop_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
