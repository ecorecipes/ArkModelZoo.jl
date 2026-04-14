function erosion_world(; initial_capacity::Int = 64)
    return World(ERDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function erosion_systems()
    return (InitErosionSystem(), ErosionGoSystem(), ErosionTerminationSystem())
end

function erosion_model(params::ERParams = ERParams())
    world = erosion_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, ERGrid(params.grid_width, params.grid_height))
    add_resource!(world, ERStats())
    scheduler = Scheduler(world, erosion_systems())
    initialize!(scheduler)
    return scheduler
end

struct ErosionObserver end

function erosion_headers(::ErosionObserver)
    return ["MeanElevation", "TotalWater"]
end

function erosion_values(::ErosionObserver, world::World)
    stats = get_resource(world, ERStats)
    return Float64[stats.mean_elevation, stats.total_water]
end

function run_erosion(; params::ERParams = ERParams(), observe::Bool = true)
    scheduler = erosion_model(params)
    obs = ErosionObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, erosion_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, erosion_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
