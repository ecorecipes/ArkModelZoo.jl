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
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = bombscenario_model(params)
    obs = BombObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, bombscenario_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, bombscenario_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
