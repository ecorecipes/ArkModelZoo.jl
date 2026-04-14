function decay_world(; initial_capacity::Int = 4096)
    return World(
        NucleusPosition,
        ActiveNucleus,
        JustDecayed,
        DecayedNucleus;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function decay_systems()
    return (
        InitDecaySystem(),
        DecaySystem(),
        DecayStatsSystem(),
        DecayTerminationSystem(),
    )
end

function decay_model(params::DecayParams = DecayParams())
    world = decay_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, DecayStats())
    scheduler = Scheduler(world, decay_systems())
    initialize!(scheduler)
    return scheduler
end

struct DecayObserver end

function decay_headers(::DecayObserver)
    return ["Decays"]
end

function decay_values(::DecayObserver, world::World)
    stats = get_resource(world, DecayStats)
    return Float64[stats.decays]
end

function run_decay(; params::DecayParams = DecayParams(), observe::Bool = true)
    scheduler = decay_model(params)
    obs = DecayObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, decay_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, decay_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
