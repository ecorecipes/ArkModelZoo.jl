function simplemarket_world(; initial_capacity::Int = 128)
    return World(SMktDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function simplemarket_systems()
    return (
        InitSMktSystem(),
        SMktGoSystem(),
        SMktTerminationSystem(),
    )
end

function simplemarket_model(params::SMktParams = SMktParams())
    world = simplemarket_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, SMktState())
    add_resource!(world, SMktStats())
    scheduler = Scheduler(world, simplemarket_systems())
    initialize!(scheduler)
    return scheduler
end

struct SMktObserver end

function simplemarket_headers(::SMktObserver)
    return ["active_shoppers", "empty_traders"]
end

function simplemarket_values(::SMktObserver, world::World)
    stats = get_resource(world, SMktStats)
    return Float64[stats.active_shoppers, stats.empty_traders]
end

function run_simplemarket(; params::SMktParams = SMktParams(), observe::Bool = true)
    scheduler = simplemarket_model(params)
    obs = SMktObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, simplemarket_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, simplemarket_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
