function minoritygame_world(; initial_capacity::Int = 4096)
    return World(MGAgent; initial_capacity = initial_capacity, allow_mutable = true)
end

function minoritygame_systems()
    return (InitMGSystem(), MGGoSystem(), MGTerminationSystem())
end

function minoritygame_model(params::MGParams = MGParams())
    world = minoritygame_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, MGState())
    add_resource!(world, MGStats())
    scheduler = Scheduler(world, minoritygame_systems())
    initialize!(scheduler)
    return scheduler
end

struct MGObserver end

function minoritygame_headers(::MGObserver)
    return ["AvgScore", "StdevScore", "NumPickingZero"]
end

function minoritygame_values(::MGObserver, world::World)
    stats = get_resource(world, MGStats)
    return Float64[stats.avg_score, stats.stdev_score, Float64(stats.num_picking_zero)]
end

function run_minoritygame(; params::MGParams = MGParams(), observe::Bool = true)
    scheduler = minoritygame_model(params)
    obs = MGObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, minoritygame_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, minoritygame_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
