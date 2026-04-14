function spatialopinion_world(; initial_capacity::Int = 128)
    return World(SOpnDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function spatialopinion_systems()
    return (InitSOpnSystem(), SOpnGoSystem(), SOpnTerminationSystem())
end

function spatialopinion_model(params::SOpnParams = SOpnParams())
    w = params.grid_xmax - params.grid_xmin + 1
    h = params.grid_ymax - params.grid_ymin + 1
    world = spatialopinion_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, SOpnGrid(w, h))
    add_resource!(world, SOpnStats())
    scheduler = Scheduler(world, spatialopinion_systems())
    initialize!(scheduler)
    return scheduler
end

struct SOpnObserver end

function spatialopinion_headers(::SOpnObserver)
    return ["Fizz", "LeftFreq", "RightFreq"]
end

function spatialopinion_values(::SOpnObserver, world::World)
    stats = get_resource(world, SOpnStats)
    return Float64[stats.fizz, stats.left_freq, stats.right_freq]
end

function run_spatialopinion(; params::SOpnParams = SOpnParams(), observe::Bool = true)
    scheduler = spatialopinion_model(params)
    obs = SOpnObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, spatialopinion_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, spatialopinion_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
