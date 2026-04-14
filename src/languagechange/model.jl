function languagechange_world(; initial_capacity::Int = 4096)
    return World(LCNode; initial_capacity = initial_capacity, allow_mutable = true)
end

function languagechange_systems()
    return (InitLCSystem(), LCGoSystem(), LCTerminationSystem())
end

function languagechange_model(params::LCParams = LCParams())
    world = languagechange_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, LCNetwork())
    add_resource!(world, LCStats())
    scheduler = Scheduler(world, languagechange_systems())
    initialize!(scheduler)
    return scheduler
end

struct LCObserver end

function languagechange_headers(::LCObserver)
    return ["MeanState", "NumGrammar0", "NumGrammar1"]
end

function languagechange_values(::LCObserver, world::World)
    stats = get_resource(world, LCStats)
    return Float64[stats.mean_state, Float64(stats.num_grammar_0), Float64(stats.num_grammar_1)]
end

function run_languagechange(; params::LCParams = LCParams(), observe::Bool = true)
    scheduler = languagechange_model(params)
    obs = LCObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, languagechange_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, languagechange_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
