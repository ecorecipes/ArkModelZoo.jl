function bombscenario_world(; initial_capacity::Int = 4096)
    return World(
        BombPosition,
        OfficerTag,
        CitizenTag,
        BomberTag,
        BombCitizenState;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function bombscenario_systems()
    return (
        InitBombSystem(),
        BombSpawnSystem(),
        BombCitizenMoveSystem(),
        BombOfficerSystem(),
        BombTerminationSystem(),
    )
end

function bombscenario_model(params::BombParams = BombParams())
    world = bombscenario_world()
    _add_standard_resources!(world, params)
    add_resource!(world, BombGrid(93, 535))
    add_resource!(world, BombStats())
    scheduler = Scheduler(world, bombscenario_systems())
    initialize!(scheduler)
    return scheduler
end

struct BombObserver end

function bombscenario_headers(::BombObserver)
    return ["ArrestedTotal"]
end

function bombscenario_values(::BombObserver, world::World)
    stats = get_resource(world, BombStats)
    return Float64[Float64(stats.arrested_total)]
end

function run_bombscenario(; params::BombParams = BombParams(), observe::Bool = true)
    return _run_model(bombscenario_model, BombObserver(), bombscenario_values; params, observe)
end
