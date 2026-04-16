function erosion_world(; initial_capacity::Int = 64)
    return World(ERDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function erosion_systems()
    return (InitErosionSystem(), ErosionGoSystem(), ErosionTerminationSystem())
end

function erosion_model(params::ERParams = ERParams())
    world = erosion_world()
    _add_standard_resources!(world, params)
    add_resource!(world, ERGrid(params.grid_width, params.grid_height))
    add_resource!(world, ERStats())
    scheduler = Scheduler(world, erosion_systems())
    initialize!(scheduler)
    return scheduler
end

struct ErosionObserver end

function erosion_headers(::ErosionObserver)
    return ["MeanElevation", "TotalWater"]
end

function erosion_values(::ErosionObserver, world::World)
    stats = get_resource(world, ERStats)
    return Float64[stats.mean_elevation, stats.total_water]
end

function run_erosion(; params::ERParams = ERParams(), observe::Bool = true)
    return _run_model(erosion_model, ErosionObserver(), erosion_values; params, observe)
end
