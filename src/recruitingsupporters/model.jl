function recruitingsupporters_world(; initial_capacity::Int = 128)
    return World(RecSupDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function recruitingsupporters_systems()
    return (
        InitRecSupSystem(),
        RecSupGoSystem(),
        RecSupTerminationSystem(),
    )
end

function recruitingsupporters_model(params::RecSupParams = RecSupParams())
    world = recruitingsupporters_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, RecSupState())
    add_resource!(world, RecSupStats())
    scheduler = Scheduler(world, recruitingsupporters_systems())
    initialize!(scheduler)
    return scheduler
end

struct RecSupObserver end

function recruitingsupporters_headers(::RecSupObserver)
    return ["recruitpct", "resistpct", "neutralpct"]
end

function recruitingsupporters_values(::RecSupObserver, world::World)
    stats = get_resource(world, RecSupStats)
    return Float64[stats.recruitpct, stats.resistpct, stats.neutralpct]
end

function run_recruitingsupporters(; params::RecSupParams = RecSupParams(), observe::Bool = true)
    scheduler = recruitingsupporters_model(params)
    obs = RecSupObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, recruitingsupporters_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, recruitingsupporters_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
