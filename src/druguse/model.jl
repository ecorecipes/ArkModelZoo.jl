function druguse_world(; initial_capacity::Int = 256)
    return World(
        DrugPosition,
        DrugHeading,
        DrugState;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function druguse_systems()
    return (
        InitDrugUseSystem(),
        DrugGoSystem(),
        DrugTerminationSystem(),
    )
end

function druguse_model(params::DrugUseParams = DrugUseParams())
    world = druguse_world()
    _add_standard_resources!(world, params)
    add_resource!(world, DrugGrid(params.grid_size, params.grid_size))
    add_resource!(world, DrugNetwork())
    add_resource!(world, DrugStats())
    scheduler = Scheduler(world, druguse_systems())
    initialize!(scheduler)
    return scheduler
end

struct DrugUseObserver end

function druguse_headers(::DrugUseObserver)
    return ["NumberOverdoses", "Population"]
end

function druguse_values(::DrugUseObserver, world::World)
    stats = get_resource(world, DrugStats)
    return Float64[stats.number_overdoses, stats.population]
end

function run_druguse(; params::DrugUseParams = DrugUseParams(), observe::Bool = true)
    return _run_model(druguse_model, DrugUseObserver(), druguse_values; params, observe)
end
