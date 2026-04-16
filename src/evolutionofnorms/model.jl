function evolutionofnorms_world(; initial_capacity::Int = 256)
    return World(
        NormAgent;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function evolutionofnorms_systems()
    return (
        InitNormSystem(),
        NormInteractionSystem(),
        NormReproductionSystem(),
        NormStatsSystem(),
        NormTerminationSystem(),
    )
end

function evolutionofnorms_model(params::NormParams = NormParams())
    world = evolutionofnorms_world()
    _add_standard_resources!(world, params)
    add_resource!(world, NormStats())
    scheduler = Scheduler(world, evolutionofnorms_systems())
    initialize!(scheduler)
    return scheduler
end

struct NormObserver end

function norm_headers(::NormObserver)
    return ["MeanPoints", "SDPoints"]
end

function norm_values(::NormObserver, world::World)
    stats = get_resource(world, NormStats)
    return Float64[stats.mean_points, stats.sd_points]
end

function run_evolutionofnorms(; params::NormParams = NormParams(), observe::Bool = true)
    return _run_model(evolutionofnorms_model, NormObserver(), norm_values; params, observe)
end
