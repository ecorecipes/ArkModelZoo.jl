function beinggreen_world(; initial_capacity::Int = 512)
    return World(
        GreenPosition,
        GreenHeading,
        ActionTaker,
        GreenProperties;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function beinggreen_systems()
    return (
        InitBeingGreenSystem(),
        MoveBeingGreenSystem(),
        InteractBeingGreenSystem(),
        TestBeingGreenSystem(),
        BeingGreenTerminationSystem(),
    )
end

function beinggreen_model(params::BeingGreenParams = BeingGreenParams())
    world = beinggreen_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, BeingGreenGrid(params.grid_width, params.grid_height))
    add_resource!(world, BeingGreenStats())
    scheduler = Scheduler(world, beinggreen_systems())
    initialize!(scheduler)
    return scheduler
end

struct BeingGreenObserver end

function beinggreen_headers(::BeingGreenObserver)
    return ["NActionTakers"]
end

function beinggreen_values(::BeingGreenObserver, world::World)
    stats = get_resource(world, BeingGreenStats)
    return Float64[stats.n_action_takers]
end

function run_beinggreen(; params::BeingGreenParams = BeingGreenParams(), observe::Bool = true)
    scheduler = beinggreen_model(params)
    obs = BeingGreenObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, beinggreen_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, beinggreen_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
