function virus_world(; initial_capacity::Int = 512)
    return World(
        VPosition,
        VHeading,
        VirusState,
        VirusTimer;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function virus_systems()
    return (
        InitVirusSystem(),
        VirusSpreadSystem(),
        VirusResistanceSystem(),
        VirusStatsSystem(),
        VirusTerminationSystem(),
    )
end

function virus_model(params::VirusParams = VirusParams())
    world = virus_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, VirusStats())
    add_resource!(world, VirusNetwork())
    scheduler = Scheduler(world, virus_systems())
    initialize!(scheduler)
    return scheduler
end

struct VirusObserver end

function virus_headers(::VirusObserver)
    return ["NumSusceptible", "NumInfected", "NumResistant"]
end

function virus_values(::VirusObserver, world::World)
    stats = get_resource(world, VirusStats)
    return Float64[stats.num_susceptible, stats.num_infected, stats.num_resistant]
end

function run_virus(; params::VirusParams = VirusParams(), observe::Bool = true)
    scheduler = virus_model(params)
    obs = VirusObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, virus_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, virus_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
