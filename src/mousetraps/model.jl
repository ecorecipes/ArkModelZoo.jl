function mousetraps_world(; initial_capacity::Int = 4096)
    return World(
        BallPosition;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function mousetraps_systems()
    return (
        InitMousetrapSystem(),
        MousetrapSystem(),
        MousetrapStatsSystem(),
        MousetrapTerminationSystem(),
    )
end

function mousetraps_model(params::MousetrapParams = MousetrapParams())
    world = mousetraps_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, MousetrapGrid(params.half_width))
    add_resource!(world, MousetrapStats())
    scheduler = Scheduler(world, mousetraps_systems())
    initialize!(scheduler)
    return scheduler
end

struct MousetrapObserver end

function mousetraps_headers(::MousetrapObserver)
    return ["TrapsTriggered", "BallsInAir"]
end

function mousetraps_values(::MousetrapObserver, world::World)
    stats = get_resource(world, MousetrapStats)
    return Float64[stats.traps_triggered, stats.balls_in_air]
end

function run_mousetraps(; params::MousetrapParams = MousetrapParams(), observe::Bool = true)
    scheduler = mousetraps_model(params)
    obs = MousetrapObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, mousetraps_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, mousetraps_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
