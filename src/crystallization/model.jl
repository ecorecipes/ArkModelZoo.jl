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
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = crystallization_model(params)
    obs = CrystallizationObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, crystallization_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, crystallization_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
