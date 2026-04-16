function schelling_world(; initial_capacity::Int = 4096)
    return World(SchPosition, SchColor, SchHappiness; initial_capacity = initial_capacity, allow_mutable = true)
end

function schelling_systems()
    return (InitSchSystem(), SchMoveUnhappySystem(), SchUpdateHappinessSystem(), SchTerminationSystem())
end

function schelling_model(params::SchParams = SchParams())
    world = schelling_world()
    _add_standard_resources!(world, params)
    add_resource!(world, SchGrid(params.grid_width, params.grid_height))
    add_resource!(world, SchStats())
    scheduler = Scheduler(world, schelling_systems())
    initialize!(scheduler)
    return scheduler
end

struct SchObserver end

function schelling_headers(::SchObserver)
    return ["PercentSimilar", "PercentUnhappy"]
end

function schelling_values(::SchObserver, world::World)
    stats = get_resource(world, SchStats)
    return Float64[stats.percent_similar, stats.percent_unhappy]
end

function run_schelling(; params::SchParams = SchParams(), observe::Bool = true)
    return _run_model(schelling_model, SchObserver(), schelling_values; params, observe)
end
