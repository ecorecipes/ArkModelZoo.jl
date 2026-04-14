function leonarditechadoption_world(; initial_capacity::Int = 128)
    return World(LTechDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function leonarditechadoption_systems()
    return (
        InitLTechSystem(),
        LTechGoSystem(),
        LTechTerminationSystem(),
    )
end

function leonarditechadoption_model(params::LTechParams = LTechParams())
    world = leonarditechadoption_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, LTechState())
    add_resource!(world, LTechStats())
    scheduler = Scheduler(world, leonarditechadoption_systems())
    initialize!(scheduler)
    return scheduler
end

struct LTechObserver end

function leonarditechadoption_headers(::LTechObserver)
    return ["n_users", "n_active"]
end

function leonarditechadoption_values(::LTechObserver, world::World)
    stats = get_resource(world, LTechStats)
    return Float64[stats.n_users, stats.n_active]
end

function run_leonarditechadoption(; params::LTechParams = LTechParams(), observe::Bool = true)
    scheduler = leonarditechadoption_model(params)
    obs = LTechObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, leonarditechadoption_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, leonarditechadoption_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
