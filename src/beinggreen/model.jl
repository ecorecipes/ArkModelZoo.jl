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
    _add_standard_resources!(world, params)
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
    return _run_model(beinggreen_model, BeingGreenObserver(), beinggreen_values; params, observe)
end
