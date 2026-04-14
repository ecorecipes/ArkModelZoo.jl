function cyber_world(; initial_capacity::Int = 128)
    return World(CyberDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function cyber_systems()
    return (
        InitCyberSystem(),
        CyberSpreadSystem(),
        CyberRecoverSystem(),
        CyberStatsSystem(),
        CyberTerminationSystem(),
    )
end

function cyber_model(params::CyberParams = CyberParams())
    world = cyber_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, CyberGrid(params.grid_size, params.grid_size))
    add_resource!(world, CyberNetwork(params.grid_size * params.grid_size))
    add_resource!(world, CyberStats())
    scheduler = Scheduler(world, cyber_systems())
    initialize!(scheduler)
    return scheduler
end

struct CyberObserver end

function cyber_headers(::CyberObserver)
    return ["NInfected", "NRecovered", "NSusceptible"]
end

function cyber_values(::CyberObserver, world::World)
    stats = get_resource(world, CyberStats)
    return Float64[stats.n_infected, stats.n_recovered, stats.n_susceptible]
end

function run_cyber(; params::CyberParams = CyberParams(), observe::Bool = true)
    scheduler = cyber_model(params)
    obs = CyberObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, cyber_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, cyber_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
