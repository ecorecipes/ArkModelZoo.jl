function coordination_world(; initial_capacity::Int = 2048)
    return World(
        CoordPosition,
        CoordNorm,
        CoordPayoff;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function coordination_systems()
    return (
        InitCoordSystem(),
        CalcPayoffsSystem(),
        EvolveSystem(),
        CoordStatsSystem(),
        CoordTerminationSystem(),
    )
end

function coordination_model(params::CoordinationParams = CoordinationParams())
    world = coordination_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, CoordStats())
    scheduler = Scheduler(world, coordination_systems())
    initialize!(scheduler)
    return scheduler
end

struct CoordinationObserver end

function coordination_headers(::CoordinationObserver)
    return ["NNorm1"]
end

function coordination_values(::CoordinationObserver, world::World)
    stats = get_resource(world, CoordStats)
    return Float64[stats.n_norm1]
end

function run_coordination(; params::CoordinationParams = CoordinationParams(), observe::Bool = true)
    scheduler = coordination_model(params)
    obs = CoordinationObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, coordination_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, coordination_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
