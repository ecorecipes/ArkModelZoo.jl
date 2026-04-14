function simplemarkettable_world(; initial_capacity::Int = 128)
    return World(SMktTDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function simplemarkettable_systems()
    return (
        InitSMktTSystem(),
        SMktTGoSystem(),
        SMktTTerminationSystem(),
    )
end

function simplemarkettable_model(params::SMktTParams = SMktTParams())
    world = simplemarkettable_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, SMktTState())
    add_resource!(world, SMktTStats())
    scheduler = Scheduler(world, simplemarkettable_systems())
    initialize!(scheduler)
    return scheduler
end

struct SMktTObserver end

function simplemarkettable_headers(::SMktTObserver)
    return ["n_shoppers_alive", "total_paces"]
end

function simplemarkettable_values(::SMktTObserver, world::World)
    stats = get_resource(world, SMktTStats)
    return Float64[stats.n_shoppers_alive, stats.total_paces]
end

function run_simplemarkettable(; params::SMktTParams = SMktTParams(), observe::Bool = true)
    scheduler = simplemarkettable_model(params)
    obs = SMktTObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, simplemarkettable_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, simplemarkettable_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
