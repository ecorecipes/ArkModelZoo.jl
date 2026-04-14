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
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = diffusion_model(params)
    obs = DiffusionObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, diffusion_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, diffusion_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
