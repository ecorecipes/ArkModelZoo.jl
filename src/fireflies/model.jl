function ff_world(; initial_capacity::Int = 4096)
    return World(FFFirefly; initial_capacity = initial_capacity, allow_mutable = true)
end

function ff_systems()
    return (InitFFSystem(), FFGoSystem(), FFTerminationSystem())
end

function ff_model(params::FFParams = FFParams())
    world = ff_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, FFStats())
    scheduler = Scheduler(world, ff_systems())
    initialize!(scheduler)
    return scheduler
end

struct FFObserver end

function ff_headers(::FFObserver)
    return ["NumFlashing"]
end

function ff_values(::FFObserver, world::World)
    stats = get_resource(world, FFStats)
    return Float64[Float64(stats.num_flashing)]
end

function run_fireflies(; params::FFParams = FFParams(), observe::Bool = true)
    scheduler = ff_model(params)
    obs = FFObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, ff_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, ff_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
