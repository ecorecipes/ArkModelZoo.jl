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
    _add_standard_resources!(world, params)
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
    return _run_model(paretolearn_model, ParetoLearnObserver(), paretolearn_values; params, observe)
end
