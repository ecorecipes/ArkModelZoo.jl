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
    _add_standard_resources!(world, params)
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
    return _run_model(birthrates_model, BirthRatesObserver(), birthrates_values; params, observe)
end
