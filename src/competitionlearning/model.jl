function competitionlearning_world(; initial_capacity::Int = 128)
    return World(CLDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function competitionlearning_systems()
    return (
        InitCLSystem(),
        CLGoSystem(),
        CLTerminationSystem(),
    )
end

function competitionlearning_model(params::CLParams = CLParams())
    world = competitionlearning_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, CLState())
    add_resource!(world, CLStats())
    scheduler = Scheduler(world, competitionlearning_systems())
    initialize!(scheduler)
    return scheduler
end

struct CLObserver end

function competitionlearning_headers(::CLObserver)
    return ["mean_strategy", "min_strategy"]
end

function competitionlearning_values(::CLObserver, world::World)
    stats = get_resource(world, CLStats)
    return Float64[stats.mean_strategy, stats.min_strategy]
end

function run_competitionlearning(; params::CLParams = CLParams(), observe::Bool = true)
    scheduler = competitionlearning_model(params)
    obs = CLObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, competitionlearning_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, competitionlearning_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
