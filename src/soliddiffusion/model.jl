function soliddiffusion_world(; initial_capacity::Int = 128)
    return World(SDDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function soliddiffusion_systems()
    return (
        InitSDSystem(),
        SDUpdateSystem(),
        SDTerminationSystem(),
    )
end

function soliddiffusion_model(params::SolidDiffusionParams = SolidDiffusionParams())
    world = soliddiffusion_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, SDGrid(params.grid_width, params.grid_height))
    add_resource!(world, SDStats())
    scheduler = Scheduler(world, soliddiffusion_systems())
    initialize!(scheduler)
    return scheduler
end

struct SolidDiffusionObserver end

function soliddiffusion_headers(::SolidDiffusionObserver)
    return ["NTurtles"]
end

function soliddiffusion_values(::SolidDiffusionObserver, world::World)
    stats = get_resource(world, SDStats)
    return Float64[stats.n_turtles]
end

function run_soliddiffusion(; params::SolidDiffusionParams = SolidDiffusionParams(), observe::Bool = true)
    scheduler = soliddiffusion_model(params)
    obs = SolidDiffusionObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, soliddiffusion_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, soliddiffusion_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
