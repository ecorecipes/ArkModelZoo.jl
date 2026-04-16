function ants_world(; initial_capacity::Int = 1024)
    return World(
        AntPosition,
        Heading,
        AntID,
        CarryingFood;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function ants_systems(grid_size::Int = 71)
    return (
        InitAntsSystem(),
        ForagingBehaviorSystem(),
        AntMovementSystem(),
        PheromoneSystem(grid_size),
        UpdateFoodStatsSystem(),
        AntsTerminationSystem(),
    )
end

function ants_model(params::AntsParams = AntsParams())
    world = ants_world()
    _add_standard_resources!(world, params)
    add_resource!(world, PatchGrid(params.grid_size, params.grid_size))
    add_resource!(world, AntsStats())
    scheduler = Scheduler(world, ants_systems(params.grid_size))
    initialize!(scheduler)
    return scheduler
end

struct AntsObserver end

function ants_headers(::AntsObserver)
    return ["TotalFood", "TotalFoodRemaining", "Source1", "Source2", "Source3"]
end

function ants_values(::AntsObserver, world::World)
    stats = get_resource(world, AntsStats)
    return Float64[stats.total_food_collected, stats.total_food_remaining,
                    stats.food_source1, stats.food_source2, stats.food_source3]
end

function run_ants(; params::AntsParams = AntsParams(), observe::Bool = true)
    return _run_model(ants_model, AntsObserver(), ants_values; params, observe)
end
