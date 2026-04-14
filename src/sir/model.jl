function sir_world(; initial_capacity::Int = 1024)
    return World(
        SIRPosition,
        SIRHeading,
        DaysInfected,
        SIRSusceptible,
        SIRInfected,
        SIRRecovered;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function sir_systems()
    return (
        InitSIRSystem(),
        SIRMovementSystem(),
        SIRInfectionSystem(),
        SIRStatsSystem(),
        SIRTerminationSystem(),
    )
end

function sir_model(params::SIRParams = SIRParams())
    world = sir_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, SIRStats())
    scheduler = Scheduler(world, sir_systems())
    initialize!(scheduler)
    return scheduler
end

struct SIRObserver end

function sir_headers(::SIRObserver)
    return ["NumSusceptible", "NumInfected", "NumRecovered"]
end

function sir_values(::SIRObserver, world::World)
    stats = get_resource(world, SIRStats)
    return Float64[stats.num_susceptible, stats.num_infected, stats.num_recovered]
end

function run_sir(; params::SIRParams = SIRParams(), observe::Bool = true)
    scheduler = sir_model(params)
    obs = SIRObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, sir_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, sir_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
