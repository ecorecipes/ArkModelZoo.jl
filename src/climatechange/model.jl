function climatechange_world(; initial_capacity::Int = 1024)
    return World(
        ClimateParticle;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function climatechange_systems()
    return (
        InitClimateChangeSystem(),
        RunSunshineSystem(),
        RunHeatSystem(),
        RunIRSystem(),
        RunCO2System(),
        ClimateChangeTerminationSystem(),
    )
end

function climatechange_model(params::ClimateChangeParams = ClimateChangeParams())
    world = climatechange_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, ClimateStats())
    scheduler = Scheduler(world, climatechange_systems())
    initialize!(scheduler)
    return scheduler
end

struct ClimateChangeObserver end

function climatechange_headers(::ClimateChangeObserver)
    return ["Temperature"]
end

function climatechange_values(::ClimateChangeObserver, world::World)
    stats = get_resource(world, ClimateStats)
    return Float64[stats.temperature]
end

function run_climatechange(; params::ClimateChangeParams = ClimateChangeParams(), observe::Bool = true)
    scheduler = climatechange_model(params)
    obs = ClimateChangeObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, climatechange_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, climatechange_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
