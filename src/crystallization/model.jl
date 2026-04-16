function crystallization_world(; initial_capacity::Int = 128)
    return World(CrystDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function crystallization_systems()
    return (
        InitCrystSystem(),
        CrystCoolSystem(),
        CrystRotateSystem(),
        CrystStatsSystem(),
        CrystTerminationSystem(),
    )
end

function crystallization_model(params::CrystallizationParams = CrystallizationParams())
    world = crystallization_world()
    _add_standard_resources!(world, params)
    add_resource!(world, CrystGrid(params.metal_size))
    add_resource!(world, CrystStats())
    scheduler = Scheduler(world, crystallization_systems())
    initialize!(scheduler)
    return scheduler
end

struct CrystallizationObserver end

function crystallization_headers(::CrystallizationObserver)
    return ["AveMetalTemp", "NumFrozen"]
end

function crystallization_values(::CrystallizationObserver, world::World)
    stats = get_resource(world, CrystStats)
    return Float64[stats.ave_metal_temp, Float64(stats.num_frozen)]
end

function run_crystallization(; params::CrystallizationParams = CrystallizationParams(), observe::Bool = true)
    return _run_model(crystallization_model, CrystallizationObserver(), crystallization_values; params, observe)
end
