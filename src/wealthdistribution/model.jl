function wealthdistribution_world(; initial_capacity::Int = 4096)
    return World(
        WDPosition,
        WDHeading,
        WDTurtle,
        WDTag;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function wealthdistribution_systems()
    return (
        InitWDSystem(),
        WDTurnSystem(),
        WDHarvestSystem(),
        WDMoveEatAgeDieSystem(),
        WDGrowGrainSystem(),
        WDGiniSystem(),
        WDTerminationSystem(),
    )
end

function wealthdistribution_model(params::WDParams = WDParams())
    world = wealthdistribution_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, WDGrid(params.grid_width, params.grid_height))
    add_resource!(world, WDStats())
    scheduler = Scheduler(world, wealthdistribution_systems())
    initialize!(scheduler)
    return scheduler
end

struct WDObserver end

function wealthdistribution_headers(::WDObserver)
    return ["GiniIndex"]
end

function wealthdistribution_values(::WDObserver, world::World)
    stats = get_resource(world, WDStats)
    return Float64[stats.gini_index_reserve]
end

function run_wealthdistribution(; params::WDParams = WDParams(), observe::Bool = true)
    scheduler = wealthdistribution_model(params)
    obs = WDObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, wealthdistribution_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, wealthdistribution_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
