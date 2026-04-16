function opinionbc_world(; initial_capacity::Int = 128)
    return World(
        OpinionBCDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function opinionbc_systems()
    return (
        InitOpinionBCSystem(),
        OpinionBCUpdateSystem(),
        OpinionBCStatsSystem(),
        OpinionBCTerminationSystem(),
    )
end

function opinionbc_model(params::OpinionBCParams = OpinionBCParams())
    world = opinionbc_world()
    _add_standard_resources!(world, params)
    add_resource!(world, OpinionBCPopulation(params.num_agents))
    add_resource!(world, OpinionBCStats())
    scheduler = Scheduler(world, opinionbc_systems())
    initialize!(scheduler)
    return scheduler
end

struct OpinionBCObserver end

function opinionbc_headers(::OpinionBCObserver)
    return ["MeanOpinion", "SDOpinion"]
end

function opinionbc_values(::OpinionBCObserver, world::World)
    stats = get_resource(world, OpinionBCStats)
    return Float64[stats.mean_opinion, stats.sd_opinion]
end

function run_opinionbc(; params::OpinionBCParams = OpinionBCParams(), observe::Bool = true)
    return _run_model(opinionbc_model, OpinionBCObserver(), opinionbc_values; params, observe)
end
