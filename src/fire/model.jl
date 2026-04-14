function fire_world(; initial_capacity::Int = 8192)
    return World(
        FirePosition,
        FireTag,
        EmberTag,
        EmberColor;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function fire_systems()
    return (
        InitFireSystem(),
        FireSpreadSystem(),
        EmberFadeSystem(),
        FireTerminationSystem(),
    )
end

function fire_model(params::FireParams = FireParams())
    world = fire_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, FireGrid(params.grid_width, params.grid_height))
    add_resource!(world, FireStats())
    scheduler = Scheduler(world, fire_systems())
    initialize!(scheduler)
    return scheduler
end

struct FireObserver end

function fire_headers(::FireObserver)
    return ["InitialTrees", "BurnedTrees"]
end

function fire_values(::FireObserver, world::World)
    stats = get_resource(world, FireStats)
    return Float64[stats.initial_trees, stats.burned_trees]
end

function run_fire(; params::FireParams = FireParams(), observe::Bool = true)
    scheduler = fire_model(params)
    obs = FireObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, fire_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, fire_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
