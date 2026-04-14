function traffic2lanes_world(; initial_capacity::Int = 4096)
    return World(T2LCar; initial_capacity = initial_capacity, allow_mutable = true)
end

function traffic2lanes_systems()
    return (InitT2LSystem(), T2LGoSystem(), T2LTerminationSystem())
end

function traffic2lanes_model(params::T2LParams = T2LParams())
    world = traffic2lanes_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, T2LRoad(params.road_length))
    add_resource!(world, T2LStats())
    scheduler = Scheduler(world, traffic2lanes_systems())
    initialize!(scheduler)
    return scheduler
end

struct T2LObserver end

function traffic2lanes_headers(::T2LObserver)
    return ["MeanSpeed", "NumLaneChanges"]
end

function traffic2lanes_values(::T2LObserver, world::World)
    stats = get_resource(world, T2LStats)
    return Float64[stats.mean_speed, Float64(stats.num_lane_changes)]
end

function run_traffic2lanes(; params::T2LParams = T2LParams(), observe::Bool = true)
    scheduler = traffic2lanes_model(params)
    obs = T2LObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, traffic2lanes_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, traffic2lanes_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
