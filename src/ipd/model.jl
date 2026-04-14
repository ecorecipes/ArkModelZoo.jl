function ipd_world(; initial_capacity::Int = 128)
    return World(IPDDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function ipd_systems()
    return (
        InitIPDSystem(),
        IPDPlaySystem(),
        IPDEvolveSystem(),
        IPDStatsSystem(),
        IPDTerminationSystem(),
    )
end

function ipd_model(params::IPDParams = IPDParams())
    world = ipd_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, IPDGrid(params.grid_size, params.grid_size))
    add_resource!(world, IPDStats())
    scheduler = Scheduler(world, ipd_systems())
    initialize!(scheduler)
    return scheduler
end

struct IPDObserver end

function ipd_headers(::IPDObserver)
    return ["MeanScore"]
end

function ipd_values(::IPDObserver, world::World)
    stats = get_resource(world, IPDStats)
    return Float64[stats.mean_score]
end

function run_ipd(; params::IPDParams = IPDParams(), observe::Bool = true)
    scheduler = ipd_model(params)
    obs = IPDObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, ipd_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, ipd_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
