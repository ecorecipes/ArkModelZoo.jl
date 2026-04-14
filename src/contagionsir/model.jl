function contagionsir_world(; initial_capacity::Int = 1024)
    return World(
        CSIRPosition,
        CSIRHeading,
        CSIRState;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function contagionsir_systems()
    return (
        InitContagionSIRSystem(),
        CSIRInfectionRecoverySystem(),
        CSIRMoveSystem(),
        CSIRStatsSystem(),
        CSIRTerminationSystem(),
    )
end

function contagionsir_model(params::ContagionSIRParams = ContagionSIRParams())
    world = contagionsir_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, CSIRStats())
    scheduler = Scheduler(world, contagionsir_systems())
    initialize!(scheduler)
    return scheduler
end

struct ContagionSIRObserver end

function contagionsir_headers(::ContagionSIRObserver)
    return ["NInfected", "NImmune"]
end

function contagionsir_values(::ContagionSIRObserver, world::World)
    stats = get_resource(world, CSIRStats)
    return Float64[stats.n_infected, stats.n_immune]
end

function run_contagionsir(; params::ContagionSIRParams = ContagionSIRParams(), observe::Bool = true)
    scheduler = contagionsir_model(params)
    obs = ContagionSIRObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, contagionsir_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, contagionsir_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
