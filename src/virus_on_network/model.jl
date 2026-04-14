function von_world(; initial_capacity::Int = 1024)
    return World(VONState; initial_capacity = initial_capacity, allow_mutable = true)
end

function von_systems()
    return (InitVONSystem(), VONGoSystem(), VONTerminationSystem())
end

function von_model(params::VONParams = VONParams())
    world = von_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, VONNetwork())
    add_resource!(world, VONStats())
    scheduler = Scheduler(world, von_systems())
    initialize!(scheduler)
    return scheduler
end

struct VONObserver end

function von_headers(::VONObserver)
    return ["Susceptible", "Infected", "Resistant"]
end

function von_values(::VONObserver, world::World)
    stats = get_resource(world, VONStats)
    return Float64[stats.num_susceptible, stats.num_infected, stats.num_resistant]
end

function run_virus_on_network(; params::VONParams = VONParams(), observe::Bool = true)
    scheduler = von_model(params)
    obs = VONObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, von_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, von_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
