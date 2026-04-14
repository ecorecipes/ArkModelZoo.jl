function antsystem_world(; initial_capacity::Int = 128)
    return World(TSPDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function antsystem_systems()
    return (
        InitTSPSystem(),
        TSPAntTourSystem(),
        TSPPheromoneSystem(),
        TSPTerminationSystem(),
    )
end

function antsystem_model(params::AntSystemParams = AntSystemParams())
    world = antsystem_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, TSPGraph(params.num_nodes))
    add_resource!(world, TSPState())
    add_resource!(world, TSPStats())
    scheduler = Scheduler(world, antsystem_systems())
    initialize!(scheduler)
    return scheduler
end

struct AntSystemObserver end

function antsystem_headers(::AntSystemObserver)
    return ["BestTourCost"]
end

function antsystem_values(::AntSystemObserver, world::World)
    stats = get_resource(world, TSPStats)
    return Float64[stats.best_tour_cost]
end

function run_antsystem(; params::AntSystemParams = AntSystemParams(), observe::Bool = true)
    scheduler = antsystem_model(params)
    obs = AntSystemObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, antsystem_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, antsystem_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
