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
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = druguse_model(params)
    obs = DrugUseObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, druguse_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, druguse_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
