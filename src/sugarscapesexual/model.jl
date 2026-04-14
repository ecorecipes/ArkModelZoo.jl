function sugarscapesexual_world(; initial_capacity::Int = 1024)
    return World(SSDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function sugarscapesexual_systems()
    return (
        InitSSSystem(),
        SSGoSystem(),
        SSTerminationSystem(),
    )
end

function sugarscapesexual_model(params::SSParams = SSParams())
    world = sugarscapesexual_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, SSWorld(params.grid_width, params.grid_height))
    add_resource!(world, SSStats())
    scheduler = Scheduler(world, sugarscapesexual_systems())
    initialize!(scheduler)
    return scheduler
end

struct SSObserver end

function sugarscapesexual_headers(::SSObserver)
    return ["NumTurtles"]
end

function sugarscapesexual_values(::SSObserver, world::World)
    stats = get_resource(world, SSStats)
    return Float64[stats.num_turtles]
end

function run_sugarscapesexual(; params::SSParams = SSParams(), observe::Bool = true)
    scheduler = sugarscapesexual_model(params)
    obs = SSObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, sugarscapesexual_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, sugarscapesexual_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
