function simplemarketrandom_world(; initial_capacity::Int = 128)
    return World(SMktRDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function simplemarketrandom_systems()
    return (
        InitSMktRSystem(),
        SMktRGoSystem(),
        SMktRTerminationSystem(),
    )
end

function simplemarketrandom_model(params::SMktRParams = SMktRParams())
    world = simplemarketrandom_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, SMktRState())
    add_resource!(world, SMktRStats())
    scheduler = Scheduler(world, simplemarketrandom_systems())
    initialize!(scheduler)
    return scheduler
end

struct SMktRObserver end

function simplemarketrandom_headers(::SMktRObserver)
    return ["num_shoppers_left", "num_traders_with_stock"]
end

function simplemarketrandom_values(::SMktRObserver, world::World)
    stats = get_resource(world, SMktRStats)
    return Float64[stats.num_shoppers_left, stats.num_traders_with_stock]
end

function run_simplemarketrandom(; params::SMktRParams = SMktRParams(), observe::Bool = true)
    scheduler = simplemarketrandom_model(params)
    obs = SMktRObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, simplemarketrandom_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, simplemarketrandom_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
