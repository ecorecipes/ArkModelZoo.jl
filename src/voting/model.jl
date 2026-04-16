function vot_world(; initial_capacity::Int = 64)
    return World(; initial_capacity = initial_capacity, allow_mutable = true)
end

function vot_systems()
    return (
        InitVOTSystem(),
        VOTGoSystem(),
        VOTTerminationSystem(),
    )
end

function vot_model(params::VOTParams = VOTParams())
    world = vot_world()
    _add_standard_resources!(world, params)
    add_resource!(world, VOTGrid(params.grid_width, params.grid_height))
    add_resource!(world, VOTStats())
    scheduler = Scheduler(world, vot_systems())
    initialize!(scheduler)
    return scheduler
end

struct VOTObserver end

function vot_headers(::VOTObserver)
    return ["BlueCount", "GreenCount"]
end

function vot_values(::VOTObserver, world::World)
    stats = get_resource(world, VOTStats)
    return Float64[Float64(stats.blue_count), Float64(stats.green_count)]
end

function run_voting(; params::VOTParams = VOTParams(), observe::Bool = true)
    return _run_model(vot_model, VOTObserver(), vot_values; params, observe)
end
