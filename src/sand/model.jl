function sand_world(; initial_capacity::Int = 128)
    return World(SandDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function sand_systems()
    return (
        InitSandSystem(),
        SandUpdateSystem(),
        SandTerminationSystem(),
    )
end

function sand_model(params::SandParams = SandParams())
    world = sand_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, SandGrid(params.grid_width, params.grid_height))
    add_resource!(world, SandStats())
    scheduler = Scheduler(world, sand_systems())
    initialize!(scheduler)
    return scheduler
end

struct SandObserver end

function sand_headers(::SandObserver)
    return ["NBrown"]
end

function sand_values(::SandObserver, world::World)
    stats = get_resource(world, SandStats)
    return Float64[stats.n_brown]
end

function run_sand(; params::SandParams = SandParams(), observe::Bool = true)
    scheduler = sand_model(params)
    obs = SandObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, sand_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, sand_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
