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
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = evolutionofnorms_model(params)
    obs = NormObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, norm_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, norm_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
