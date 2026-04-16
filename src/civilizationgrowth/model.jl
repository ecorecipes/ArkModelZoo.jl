function civilizationgrowth_world(; initial_capacity::Int = 128)
    World(
        CivAgent;
        initial_capacity = initial_capacity,
        allow_mutable = true
    )
end

function civilizationgrowth_systems()
    return (
        InitCivGrowthSystem(),
        CivInvestSystem(),
        CivStatsSystem(),
        CivTerminationSystem()
    )
end

function civilizationgrowth_model(params::CivGrowthParams = CivGrowthParams())
    world = civilizationgrowth_world()
    _add_standard_resources!(world, params)
    add_resource!(world, CivGrid(params.grid_width, params.grid_height))
    add_resource!(world, CivStats())
    scheduler = Scheduler(world, civilizationgrowth_systems())
    initialize!(scheduler)
    return scheduler
end

struct CivGrowthObserver end

function civilizationgrowth_headers(::CivGrowthObserver)
    return ["n_civs"]
end

function civilizationgrowth_values(::CivGrowthObserver, world::World)
    stats = get_resource(world, CivStats)
    return Float64[Float64(stats.n_civs)]
end

function run_civilizationgrowth(; params::CivGrowthParams = CivGrowthParams(), observe::Bool = true)
    return _run_model(civilizationgrowth_model, CivGrowthObserver(), civilizationgrowth_values; params, observe)
end
