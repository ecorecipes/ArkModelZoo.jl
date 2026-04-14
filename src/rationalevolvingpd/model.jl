function rationalevolvingpd_world(; initial_capacity::Int = 128)
    return World(REPDDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function rationalevolvingpd_systems()
    return (
        InitREPDSystem(),
        REPDFindPartnersSystem(),
        REPDPlaySystem(),
        REPDEnergySystem(),
        REPDReproduceSystem(),
        REPDDeathSystem(),
        REPDStatsSystem(),
        REPDTerminationSystem(),
    )
end

function rationalevolvingpd_model(params::REPDParams = REPDParams())
    world = rationalevolvingpd_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, REPDState(params.grid_size, params.grid_size))
    add_resource!(world, REPDStats())
    scheduler = Scheduler(world, rationalevolvingpd_systems())
    initialize!(scheduler)
    return scheduler
end

struct REPDObserver end

function rationalevolvingpd_headers(::REPDObserver)
    return ["NAlive", "NNeurons"]
end

function rationalevolvingpd_values(::REPDObserver, world::World)
    stats = get_resource(world, REPDStats)
    return Float64[Float64(stats.n_alive), Float64(stats.n_neurons)]
end

function run_rationalevolvingpd(; params::REPDParams = REPDParams(), observe::Bool = true)
    scheduler = rationalevolvingpd_model(params)
    obs = REPDObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, rationalevolvingpd_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, rationalevolvingpd_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
