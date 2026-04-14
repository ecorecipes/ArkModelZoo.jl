function birthrates_world(; initial_capacity::Int = 2048)
    return World(
        BRPosition,
        BRHeading,
        RedTurtle,
        BlueTurtle;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function birthrates_systems()
    return (
        InitBirthRatesSystem(),
        BRReproduceSystem(),
        BRGrimReaperSystem(),
        BRStatsSystem(),
        BRTerminationSystem(),
    )
end

function birthrates_model(params::BirthRatesParams = BirthRatesParams())
    world = birthrates_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, BirthRatesStats())
    scheduler = Scheduler(world, birthrates_systems())
    initialize!(scheduler)
    return scheduler
end

struct BirthRatesObserver end

function birthrates_headers(::BirthRatesObserver)
    return ["RedCount", "BlueCount"]
end

function birthrates_values(::BirthRatesObserver, world::World)
    stats = get_resource(world, BirthRatesStats)
    return Float64[stats.red_count, stats.blue_count]
end

function run_birthrates(; params::BirthRatesParams = BirthRatesParams(), observe::Bool = true)
    scheduler = birthrates_model(params)
    obs = BirthRatesObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, birthrates_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, birthrates_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
