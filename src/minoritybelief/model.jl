function minoritybelief_world(; initial_capacity::Int = 128)
    return World(MBeliefDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function minoritybelief_systems()
    return (
        InitMBeliefSystem(),
        MBeliefGoSystem(),
        MBeliefTerminationSystem(),
    )
end

function minoritybelief_model(params::MBeliefParams = MBeliefParams())
    world = minoritybelief_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, MBeliefState())
    add_resource!(world, MBeliefStats())
    scheduler = Scheduler(world, minoritybelief_systems())
    initialize!(scheduler)
    return scheduler
end

struct MBeliefObserver end

function minoritybelief_headers(::MBeliefObserver)
    return ["n_magenta", "n_yellow", "n_cyan"]
end

function minoritybelief_values(::MBeliefObserver, world::World)
    stats = get_resource(world, MBeliefStats)
    return Float64[stats.n_magenta, stats.n_yellow, stats.n_cyan]
end

function run_minoritybelief(; params::MBeliefParams = MBeliefParams(), observe::Bool = true)
    scheduler = minoritybelief_model(params)
    obs = MBeliefObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, minoritybelief_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, minoritybelief_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
