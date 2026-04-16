function bb_world(; initial_capacity::Int = 64)
    return World(; initial_capacity = initial_capacity, allow_mutable = true)
end

function bb_systems()
    return (
        InitBBSystem(),
        BBGoSystem(),
        BBTerminationSystem(),
    )
end

function bb_model(params::BBParams = BBParams())
    world = bb_world()
    _add_standard_resources!(world, params)
    add_resource!(world, BBGrid(params.grid_width, params.grid_height))
    add_resource!(world, BBStats())
    scheduler = Scheduler(world, bb_systems())
    initialize!(scheduler)
    return scheduler
end

struct BBObserver end

function bb_headers(::BBObserver)
    return ["Firing", "Refractory", "Dead"]
end

function bb_values(::BBObserver, world::World)
    stats = get_resource(world, BBStats)
    return Float64[Float64(stats.firing_count), Float64(stats.refractory_count),
                    Float64(stats.dead_count)]
end

function run_brians_brain(; params::BBParams = BBParams(), observe::Bool = true)
    return _run_model(bb_model, BBObserver(), bb_values; params, observe)
end
