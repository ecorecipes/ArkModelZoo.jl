function superdiffuser_world(; initial_capacity::Int = 128)
    return World(SDiffDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function superdiffuser_systems()
    return (InitSDiffSystem(), SDiffGoSystem(), SDiffTerminationSystem())
end

function superdiffuser_model(params::SDiffParams = SDiffParams())
    world = superdiffuser_world()
    _add_standard_resources!(world, params)
    add_resource!(world, SDiffNetwork())
    add_resource!(world, SDiffStats())
    scheduler = Scheduler(world, superdiffuser_systems())
    initialize!(scheduler)
    return scheduler
end

struct SDiffObserver end

function superdiffuser_headers(::SDiffObserver)
    return ["CurrentAdopted"]
end

function superdiffuser_values(::SDiffObserver, world::World)
    stats = get_resource(world, SDiffStats)
    return Float64[stats.current_adopted]
end

function run_superdiffuser(; params::SDiffParams = SDiffParams(), observe::Bool = true)
    scheduler = superdiffuser_model(params)
    obs = SDiffObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, superdiffuser_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            # NetLogo BehaviorSpace does not record metrics on the tick where
            # `stop` is called.  Match that behaviour by skipping the observation
            # when the termination system has signalled stop during this step.
            if get_resource(scheduler.world, Terminate).stop
                break
            end
            push!(trajectory, superdiffuser_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
