function sand_world(; initial_capacity::Int = 128)
    return World(SandDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function sand_systems()
    return (
        InitSandSystem(),
        SandUpdateSystem(),
        SandTerminationSystem(),
    )
end

function sand_model(params::SandParams = SandParams())
    world = sand_world()
    _add_standard_resources!(world, params)
    add_resource!(world, SandGrid(params.grid_width, params.grid_height))
    add_resource!(world, SandStats())
    scheduler = Scheduler(world, sand_systems())
    initialize!(scheduler)
    return scheduler
end

struct SandObserver end

function sand_headers(::SandObserver)
    return ["NBrown"]
end

function sand_values(::SandObserver, world::World)
    stats = get_resource(world, SandStats)
    return Float64[stats.n_brown]
end

function run_sand(; params::SandParams = SandParams(), observe::Bool = true)
    return _run_model(sand_model, SandObserver(), sand_values; params, observe)
end
