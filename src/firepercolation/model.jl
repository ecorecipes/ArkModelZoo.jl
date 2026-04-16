function firepercolation_world(; initial_capacity::Int = 128)
    return World(
        FirePercDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function firepercolation_systems()
    return (
        InitFirePercSystem(),
        FirePercSpreadSystem(),
        FirePercStatsSystem(),
        FirePercTerminationSystem(),
    )
end

function firepercolation_model(params::FirePercolationParams = FirePercolationParams())
    world = firepercolation_world()
    _add_standard_resources!(world, params)
    add_resource!(world, FirePercGrid(params.grid_width, params.grid_height))
    add_resource!(world, FirePercStats())
    scheduler = Scheduler(world, firepercolation_systems())
    initialize!(scheduler)
    return scheduler
end

struct FirePercolationObserver end

function firepercolation_headers(::FirePercolationObserver)
    return ["FireSize"]
end

function firepercolation_values(::FirePercolationObserver, world::World)
    stats = get_resource(world, FirePercStats)
    return Float64[stats.fire_size]
end

function run_firepercolation(; params::FirePercolationParams = FirePercolationParams(), observe::Bool = true)
    return _run_model(firepercolation_model, FirePercolationObserver(), firepercolation_values; params, observe)
end
