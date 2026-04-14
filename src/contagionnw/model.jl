function contagionnw_world(; initial_capacity::Int = 128)
    return World(CNWDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function contagionnw_systems()
    return (InitContagionNWSystem(), CNWSpreadSystem(), CNWTerminationSystem())
end

function contagionnw_model(params::ContagionNWParams = ContagionNWParams())
    world = contagionnw_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, CNWNetwork())
    add_resource!(world, CNWStats())
    scheduler = Scheduler(world, contagionnw_systems())
    initialize!(scheduler)
    return scheduler
end

struct ContagionNWObserver end

function contagionnw_headers(::ContagionNWObserver)
    return ["NumInfectedNW", "NumLinksNW"]
end

function contagionnw_values(::ContagionNWObserver, world::World)
    stats = get_resource(world, CNWStats)
    return Float64[stats.num_infected, stats.num_links]
end

function run_contagionnw(; params::ContagionNWParams = ContagionNWParams(), observe::Bool = true)
    scheduler = contagionnw_model(params)
    obs = ContagionNWObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, contagionnw_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, contagionnw_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
