function infinitelife_world(; initial_capacity::Int = 128)
    return World(InfLifeDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function infinitelife_systems()
    return (
        InitInfLifeSystem(),
        InfLifeStepSystem(),
        InfLifeTerminationSystem(),
    )
end

function infinitelife_model(params::InfLifeParams = InfLifeParams())
    world = infinitelife_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, InfLifeGrid())
    add_resource!(world, InfLifeStats())
    scheduler = Scheduler(world, infinitelife_systems())
    initialize!(scheduler)
    return scheduler
end

struct InfLifeObserver end

function infinitelife_headers(::InfLifeObserver)
    return ["NCells"]
end

function infinitelife_values(::InfLifeObserver, world::World)
    stats = get_resource(world, InfLifeStats)
    return Float64[stats.n_cells]
end

function run_infinitelife(; params::InfLifeParams = InfLifeParams(), observe::Bool = true)
    scheduler = infinitelife_model(params)
    obs = InfLifeObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, infinitelife_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, infinitelife_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
