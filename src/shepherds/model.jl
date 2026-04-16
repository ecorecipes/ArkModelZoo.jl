function shepherds_world(; initial_capacity::Int = 4096)
    return World(SHSheepPos, SHShepherdState; initial_capacity = initial_capacity, allow_mutable = true)
end

function shepherds_systems()
    return (InitSHSystem(), SHGoSystem(), SHStatsSystem(), SHTerminationSystem())
end

function shepherds_model(params::SHParams = SHParams())
    world = shepherds_world()
    _add_standard_resources!(world, params)
    add_resource!(world, SHGrid(params.grid_width, params.grid_height))
    add_resource!(world, SHStats())
    scheduler = Scheduler(world, shepherds_systems())
    initialize!(scheduler)
    return scheduler
end

struct SHObserver end

function shepherds_headers(::SHObserver)
    return ["HerdingEfficiency", "NumSheepVisible"]
end

function shepherds_values(::SHObserver, world::World)
    stats = get_resource(world, SHStats)
    return Float64[stats.herding_efficiency, Float64(stats.num_sheep_visible)]
end

function run_shepherds(; params::SHParams = SHParams(), observe::Bool = true)
    return _run_model(shepherds_model, SHObserver(), shepherds_values; params, observe)
end
