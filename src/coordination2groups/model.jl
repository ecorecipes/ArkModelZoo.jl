function coordination2groups_world(; initial_capacity::Int = 2048)
    return World(
        Coord2GroupID,
        Coord2Norm1,
        Coord2Payoff;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function coordination2groups_systems()
    return (
        InitCoordination2GroupsSystem(),
        Coord2CalculatePayoffsSystem(),
        Coord2EvolveSystem(),
        Coordination2GroupsTerminationSystem(),
    )
end

function coordination2groups_model(params::Coordination2GroupsParams = Coordination2GroupsParams())
    world = coordination2groups_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, Coordination2GroupsStats())
    scheduler = Scheduler(world, coordination2groups_systems())
    initialize!(scheduler)
    return scheduler
end

struct Coordination2GroupsObserver end

function coordination2groups_headers(::Coordination2GroupsObserver)
    return ["NNorm1"]
end

function coordination2groups_values(::Coordination2GroupsObserver, world::World)
    stats = get_resource(world, Coordination2GroupsStats)
    return Float64[stats.n_norm1]
end

function run_coordination2groups(; params::Coordination2GroupsParams = Coordination2GroupsParams(), observe::Bool = true)
    scheduler = coordination2groups_model(params)
    obs = Coordination2GroupsObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, coordination2groups_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, coordination2groups_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
