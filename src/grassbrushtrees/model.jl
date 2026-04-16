function gbt_world(; initial_capacity::Int = 128)
    return World(
        GBTDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function gbt_systems()
    return (
        InitGBTSystem(),
        GBTUpdateSystem(),
        GBTStatsSystem(),
        GBTTerminationSystem(),
    )
end

function gbt_model(params::GBTParams = GBTParams())
    world = gbt_world()
    _add_standard_resources!(world, params)
    add_resource!(world, GBTGrid(params.grid_width, params.grid_height))
    add_resource!(world, GBTStats())
    scheduler = Scheduler(world, gbt_systems())
    initialize!(scheduler)
    return scheduler
end

struct GBTObserver end

function gbt_headers(::GBTObserver)
    return ["NTrees"]
end

function gbt_values(::GBTObserver, world::World)
    stats = get_resource(world, GBTStats)
    return Float64[stats.n_trees]
end

function run_gbt(; params::GBTParams = GBTParams(), observe::Bool = true)
    return _run_model(gbt_model, GBTObserver(), gbt_values; params, observe)
end
