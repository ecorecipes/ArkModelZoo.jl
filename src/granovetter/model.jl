function gran_world(; initial_capacity::Int = 256)
    return World(GRANAgent; initial_capacity = initial_capacity, allow_mutable = true)
end

function gran_systems()
    return (
        InitGRANSystem(),
        GRANGoSystem(),
        GRANTerminationSystem(),
    )
end

function gran_model(params::GRANParams = GRANParams())
    world = gran_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, GRANNetwork(params.number_of_agents))
    add_resource!(world, GRANStats())
    scheduler = Scheduler(world, gran_systems())
    initialize!(scheduler)
    return scheduler
end

struct GRANObserver end

function gran_headers(::GRANObserver)
    return ["PercentRioting", "NumRioting"]
end

function gran_values(::GRANObserver, world::World)
    stats = get_resource(world, GRANStats)
    return Float64[stats.percent_rioting, Float64(stats.num_rioting)]
end

function run_granovetter(; params::GRANParams = GRANParams(), observe::Bool = true)
    scheduler = gran_model(params)
    obs = GRANObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, gran_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, gran_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
