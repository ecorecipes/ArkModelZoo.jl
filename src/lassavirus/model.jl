function lassavirus_world(; initial_capacity::Int = 1024)
    return World(
        LassaPosition,
        LassaHeading,
        HumanState,
        RatTag;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function lassavirus_systems()
    return (
        InitLassaSystem(),
        LassaMovementSystem(),
        LassaInfectionSystem(),
        LassaStatsSystem(),
        LassaTerminationSystem(),
    )
end

function lassavirus_model(params::LassaParams = LassaParams())
    world = lassavirus_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, LassaStats())
    add_resource!(world, LassaRegistry())
    scheduler = Scheduler(world, lassavirus_systems())
    initialize!(scheduler)
    return scheduler
end

struct LassaVirusObserver end

function lassavirus_headers(::LassaVirusObserver)
    return ["PctInfected", "PctImmune", "CurrentCases", "TotalFatalities"]
end

function lassavirus_values(::LassaVirusObserver, world::World)
    stats = get_resource(world, LassaStats)
    return Float64[stats.pct_infected, stats.pct_immune, Float64(stats.current_cases), Float64(stats.total_fatalities)]
end

function run_lassavirus(; params::LassaParams = LassaParams(), observe::Bool = true)
    scheduler = lassavirus_model(params)
    obs = LassaVirusObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, lassavirus_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, lassavirus_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
