function productsmarket_world(; initial_capacity::Int = 128)
    return World(PMktDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function productsmarket_systems()
    return (InitPMktSystem(), PMktGoSystem(), PMktTerminationSystem())
end

function productsmarket_model(params::PMktParams = PMktParams())
    world = productsmarket_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, PMktNetwork())
    add_resource!(world, PMktStats())
    scheduler = Scheduler(world, productsmarket_systems())
    initialize!(scheduler)
    return scheduler
end

struct PMktObserver end

function productsmarket_headers(::PMktObserver)
    return ["CountApple", "CountSamsung"]
end

function productsmarket_values(::PMktObserver, world::World)
    stats = get_resource(world, PMktStats)
    return Float64[stats.count_apple, stats.count_samsung]
end

function run_productsmarket(; params::PMktParams = PMktParams(), observe::Bool = true)
    scheduler = productsmarket_model(params)
    obs = PMktObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, productsmarket_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, productsmarket_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
