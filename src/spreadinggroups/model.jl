function spreadinggroups_world(; initial_capacity::Int = 128)
    return World(SGroupDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function spreadinggroups_systems()
    return (InitSGroupSystem(), SGroupGoSystem(), SGroupTerminationSystem())
end

function spreadinggroups_model(params::SGroupParams = SGroupParams())
    world = spreadinggroups_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, SGroupNetwork())
    add_resource!(world, SGroupStats())
    scheduler = Scheduler(world, spreadinggroups_systems())
    initialize!(scheduler)
    return scheduler
end

struct SGroupObserver end

function spreadinggroups_headers(::SGroupObserver)
    return ["NumInfected"]
end

function spreadinggroups_values(::SGroupObserver, world::World)
    stats = get_resource(world, SGroupStats)
    return Float64[stats.num_infected]
end

function run_spreadinggroups(; params::SGroupParams = SGroupParams(), observe::Bool = true)
    scheduler = spreadinggroups_model(params)
    obs = SGroupObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, spreadinggroups_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, spreadinggroups_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
