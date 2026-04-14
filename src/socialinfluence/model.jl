function socialinfluence_world(; initial_capacity::Int = 128)
    return World(SInflDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function socialinfluence_systems()
    return (InitSInflSystem(), SInflGoSystem(), SInflTerminationSystem())
end

function socialinfluence_model(params::SInflParams = SInflParams())
    world = socialinfluence_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, SInflState())
    add_resource!(world, SInflStats())
    scheduler = Scheduler(world, socialinfluence_systems())
    initialize!(scheduler)
    return scheduler
end

struct SInflObserver end

function socialinfluence_headers(::SInflObserver)
    return ["NumberInfluence"]
end

function socialinfluence_values(::SInflObserver, world::World)
    stats = get_resource(world, SInflStats)
    return Float64[stats.number_influence]
end

function run_socialinfluence(; params::SInflParams = SInflParams(), observe::Bool = true)
    scheduler = socialinfluence_model(params)
    obs = SInflObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, socialinfluence_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, socialinfluence_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
