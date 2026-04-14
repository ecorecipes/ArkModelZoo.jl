function recruitingmovement_world(; initial_capacity::Int = 128)
    return World(RecMovDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function recruitingmovement_systems()
    return (
        InitRecMovSystem(),
        RecMovGoSystem(),
        RecMovTerminationSystem(),
    )
end

function recruitingmovement_model(params::RecMovParams = RecMovParams())
    world = recruitingmovement_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, RecMovState())
    add_resource!(world, RecMovStats())
    scheduler = Scheduler(world, recruitingmovement_systems())
    initialize!(scheduler)
    return scheduler
end

struct RecMovObserver end

function recruitingmovement_headers(::RecMovObserver)
    return ["recruitpct", "resistpct", "neutralpct"]
end

function recruitingmovement_values(::RecMovObserver, world::World)
    stats = get_resource(world, RecMovStats)
    return Float64[stats.recruitpct, stats.resistpct, stats.neutralpct]
end

function run_recruitingmovement(; params::RecMovParams = RecMovParams(), observe::Bool = true)
    scheduler = recruitingmovement_model(params)
    obs = RecMovObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, recruitingmovement_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, recruitingmovement_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
