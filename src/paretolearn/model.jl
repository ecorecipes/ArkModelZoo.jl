function paretolearn_world(; initial_capacity::Int = 128)
    return World(
        ParetoLearnDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function paretolearn_systems()
    return (
        InitParetoLearnSystem(),
        ParetoLearnUpdateSystem(),
        ParetoLearnTerminationSystem(),
    )
end

function paretolearn_model(params::ParetoLearnParams = ParetoLearnParams())
    world = paretolearn_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, ParetoLearnerState(params.exploration_rate))
    add_resource!(world, ParetoStats())
    scheduler = Scheduler(world, paretolearn_systems())
    initialize!(scheduler)
    return scheduler
end

struct ParetoLearnObserver end

function paretolearn_headers(::ParetoLearnObserver)
    return ["EUCooperate", "EUDefect"]
end

function paretolearn_values(::ParetoLearnObserver, world::World)
    stats = get_resource(world, ParetoStats)
    return Float64[stats.eu_cooperate, stats.eu_defect]
end

function run_paretolearn(; params::ParetoLearnParams = ParetoLearnParams(), observe::Bool = true)
    scheduler = paretolearn_model(params)
    obs = ParetoLearnObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, paretolearn_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, paretolearn_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
