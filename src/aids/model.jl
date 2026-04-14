function aids_world(; initial_capacity::Int = 1024)
    return World(AIDSPerson; initial_capacity = initial_capacity, allow_mutable = true)
end

function aids_systems()
    return (InitAIDSSystem(), AIDSGoSystem(), AIDSTerminationSystem())
end

function aids_model(params::AIDSParams = AIDSParams())
    world = aids_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, AIDSStats())
    scheduler = Scheduler(world, aids_systems())
    initialize!(scheduler)
    return scheduler
end

struct AIDSObserver end

function aids_headers(::AIDSObserver)
    return ["Uninfected", "InfectedUnknown", "InfectedKnown", "PctInfected"]
end

function aids_values(::AIDSObserver, world::World)
    stats = get_resource(world, AIDSStats)
    return Float64[stats.num_uninfected, stats.num_infected_unknown,
                    stats.num_infected_known, stats.pct_infected]
end

function run_aids(; params::AIDSParams = AIDSParams(), observe::Bool = true)
    scheduler = aids_model(params)
    obs = AIDSObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, aids_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, aids_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
