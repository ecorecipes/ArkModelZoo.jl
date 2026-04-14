function slime_world(; initial_capacity::Int = 4096)
    return World(
        SLPosition,
        SLHeading;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function slime_systems()
    return (
        InitSLSystem(),
        SLGoSystem(),
        SLTerminationSystem(),
    )
end

function slime_model(params::SLParams = SLParams())
    world = slime_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, SLChemicalGrid(params.grid_width, params.grid_height))
    add_resource!(world, SLStats())
    scheduler = Scheduler(world, slime_systems())
    initialize!(scheduler)
    return scheduler
end

struct SLObserver end

function slime_headers(::SLObserver)
    return ["TotalChemical", "MaxChemical", "MeanChemical"]
end

function slime_values(::SLObserver, world::World)
    stats = get_resource(world, SLStats)
    grid = get_resource(world, SLChemicalGrid)
    n_patches = grid.width * grid.height
    mean_chem = n_patches > 0 ? stats.total_chemical / n_patches : 0.0
    return Float64[stats.total_chemical, stats.max_chemical, mean_chem]
end

function run_slime(; params::SLParams = SLParams(), observe::Bool = true)
    scheduler = slime_model(params)
    obs = SLObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, slime_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, slime_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
