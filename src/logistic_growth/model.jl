function lg_world(; initial_capacity::Int = 64)
    return World(; initial_capacity = initial_capacity, allow_mutable = true)
end

function lg_systems()
    return (
        InitLGSystem(),
        LGGoSystem(),
        LGTerminationSystem(),
    )
end

function lg_model(params::LGParams = LGParams())
    world = lg_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, LGState())
    scheduler = Scheduler(world, lg_systems())
    initialize!(scheduler)
    return scheduler
end

struct LGObserver end

function lg_headers(::LGObserver)
    return ["Stock"]
end

function lg_values(::LGObserver, world::World)
    state = get_resource(world, LGState)
    return Float64[state.stock]
end

function run_logistic_growth(; params::LGParams = LGParams(), observe::Bool = true)
    scheduler = lg_model(params)
    obs = LGObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, lg_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, lg_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
