function fire_world(; initial_capacity::Int = 8192)
    return World(
        FirePosition,
        FireTag,
        EmberTag,
        EmberColor;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function fire_systems()
    return (
        InitFireSystem(),
        FireSpreadSystem(),
        EmberFadeSystem(),
        FireTerminationSystem(),
    )
end

function fire_model(params::FireParams = FireParams())
    world = fire_world()
    _add_standard_resources!(world, params)
    add_resource!(world, FireGrid(params.grid_width, params.grid_height))
    add_resource!(world, FireStats())
    scheduler = Scheduler(world, fire_systems())
    initialize!(scheduler)
    return scheduler
end

struct FireObserver end

function fire_headers(::FireObserver)
    return ["InitialTrees", "BurnedTrees"]
end

function fire_values(::FireObserver, world::World)
    stats = get_resource(world, FireStats)
    return Float64[stats.initial_trees, stats.burned_trees]
end

function run_fire(; params::FireParams = FireParams(), observe::Bool = true)
    return _run_model(fire_model, FireObserver(), fire_values; params, observe)
end
