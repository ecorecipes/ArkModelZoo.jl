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
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
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
    scheduler = firepercolation_model(params)
    obs = FirePercolationObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, firepercolation_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, firepercolation_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
