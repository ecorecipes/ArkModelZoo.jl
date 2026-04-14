function resilient_world(; initial_capacity::Int = 128)
    return World(ResilientDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function resilient_systems()
    return (
        InitResilientSystem(),
        ResilientEnvSystem(),
        ResilientPerceiveSystem(),
        ResilientDecisionSystem(),
        ResilientChangeSystem(),
        ResilientActSystem(),
        ResilientStatsSystem(),
        ResilientTerminationSystem(),
    )
end

function resilient_model(params::ResilientParams = ResilientParams())
    world = resilient_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, ResilientAgentState(params.n_agents, params.init_value, params.init_rate))
    add_resource!(world, ResilientRelationState(params.n_agents))
    add_resource!(world, ResilientEnvState(params.n_agents))
    add_resource!(world, ResilientStats())
    scheduler = Scheduler(world, resilient_systems())
    initialize!(scheduler)
    return scheduler
end

struct ResilientObserver end

function resilient_headers(::ResilientObserver)
    return ["MeanStress", "MeanResilience"]
end

function resilient_values(::ResilientObserver, world::World)
    stats = get_resource(world, ResilientStats)
    return Float64[stats.mean_stress, stats.mean_resilience]
end

function run_resilient(; params::ResilientParams = ResilientParams(), observe::Bool = true)
    scheduler = resilient_model(params)
    obs = ResilientObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, resilient_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, resilient_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
