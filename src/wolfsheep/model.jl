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
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = wolfsheep_model(params)
    obs = WolfSheepObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, wolfsheep_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, wolfsheep_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
