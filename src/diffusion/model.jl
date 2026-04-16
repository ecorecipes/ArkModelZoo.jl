function diffusion_world(; initial_capacity::Int = 128)
    return World(
        DiffusionDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function diffusion_systems()
    return (
        InitDiffusionSystem(),
        DiffusionUpdateSystem(),
        DiffusionStatsSystem(),
        DiffusionTerminationSystem(),
    )
end

function diffusion_model(params::DiffusionParams = DiffusionParams())
    world = diffusion_world()
    _add_standard_resources!(world, params)
    add_resource!(world, DiffusionGrid(params.grid_width, params.grid_height))
    add_resource!(world, DiffusionStats())
    scheduler = Scheduler(world, diffusion_systems())
    initialize!(scheduler)
    return scheduler
end

struct DiffusionObserver end

function diffusion_headers(::DiffusionObserver)
    return ["MaxTemp", "MeanTemp"]
end

function diffusion_values(::DiffusionObserver, world::World)
    stats = get_resource(world, DiffusionStats)
    return Float64[stats.max_temp, stats.mean_temp]
end

function run_diffusion(; params::DiffusionParams = DiffusionParams(), observe::Bool = true)
    return _run_model(diffusion_model, DiffusionObserver(), diffusion_values; params, observe)
end
