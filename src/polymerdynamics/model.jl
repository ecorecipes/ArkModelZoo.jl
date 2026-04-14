function polymerdynamics_world(; initial_capacity::Int = 128)
    return World(
        PolymerDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function polymerdynamics_systems()
    return (
        InitPolymerSystem(),
        PolymerUpdateSystem(),
        PolymerTerminationSystem(),
    )
end

function polymerdynamics_model(params::PolymerDynamicsParams = PolymerDynamicsParams())
    world = polymerdynamics_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, PolymerGrid(params.grid_width, params.grid_height))
    add_resource!(world, PolymerStats())
    scheduler = Scheduler(world, polymerdynamics_systems())
    initialize!(scheduler)
    return scheduler
end

struct PolymerDynamicsObserver end

function polymerdynamics_headers(::PolymerDynamicsObserver)
    return ["NTurtles"]
end

function polymerdynamics_values(::PolymerDynamicsObserver, world::World)
    stats = get_resource(world, PolymerStats)
    return Float64[stats.n_turtles]
end

function run_polymerdynamics(; params::PolymerDynamicsParams = PolymerDynamicsParams(), observe::Bool = true)
    scheduler = polymerdynamics_model(params)
    obs = PolymerDynamicsObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, polymerdynamics_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, polymerdynamics_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
