function spatialattitude_world(; initial_capacity::Int = 128)
    return World(SAttDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function spatialattitude_systems()
    return (InitSAttSystem(), SAttGoSystem(), SAttTerminationSystem())
end

function spatialattitude_model(params::SAttParams = SAttParams())
    w = params.grid_xmax - params.grid_xmin + 1
    h = params.grid_ymax - params.grid_ymin + 1
    world = spatialattitude_world()
    _add_standard_resources!(world, params)
    add_resource!(world, SAttGrid(w, h))
    add_resource!(world, SAttStats())
    scheduler = Scheduler(world, spatialattitude_systems())
    initialize!(scheduler)
    return scheduler
end

struct SAttObserver end

function spatialattitude_headers(::SAttObserver)
    return ["Fizz", "LeftFreq", "RightFreq"]
end

function spatialattitude_values(::SAttObserver, world::World)
    stats = get_resource(world, SAttStats)
    return Float64[stats.fizz, stats.left_freq, stats.right_freq]
end

function run_spatialattitude(; params::SAttParams = SAttParams(), observe::Bool = true)
    return _run_model(spatialattitude_model, SAttObserver(), spatialattitude_values; params, observe)
end
