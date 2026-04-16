function wolfsheep_world(; initial_capacity::Int = 4096)
    return World(
        WSPosition,
        Energy,
        WSHeading,
        Wolf,
        Sheep;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function wolfsheep_systems()
    return (
        InitWolfSheepSystem(),
        SheepPhaseSystem(),
        WolfPhaseSystem(),
        GrassGrowthSystem(),
        CountWSPopulationSystem(),
        WSTerminationSystem(),
    )
end

function wolfsheep_model(params::WolfSheepParams = WolfSheepParams())
    world = wolfsheep_world()
    _add_standard_resources!(world, params)
    add_resource!(world, GrassGrid(params.grid_width, params.grid_height))
    add_resource!(world, WSPopulationStats())
    scheduler = Scheduler(world, wolfsheep_systems())
    initialize!(scheduler)
    return scheduler
end

struct WolfSheepObserver end

function wolfsheep_headers(::WolfSheepObserver)
    return ["Sheep", "Wolves", "Grass"]
end

function wolfsheep_values(::WolfSheepObserver, world::World)
    stats = get_resource(world, WSPopulationStats)
    return Float64[stats.sheep_count, stats.wolf_count, stats.grass_count]
end

function run_wolfsheep(; params::WolfSheepParams = WolfSheepParams(), observe::Bool = true)
    return _run_model(wolfsheep_model, WolfSheepObserver(), wolfsheep_values; params, observe)
end
