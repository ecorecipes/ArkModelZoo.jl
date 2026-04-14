function schelling_world(; initial_capacity::Int = 4096)
    return World(SchPosition, SchColor, SchHappiness; initial_capacity = initial_capacity, allow_mutable = true)
end

function schelling_systems()
    return (InitSchSystem(), SchMoveUnhappySystem(), SchUpdateHappinessSystem(), SchTerminationSystem())
end

function schelling_model(params::SchParams = SchParams())
    world = schelling_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, SchGrid(params.grid_width, params.grid_height))
    add_resource!(world, SchStats())
    scheduler = Scheduler(world, schelling_systems())
    initialize!(scheduler)
    return scheduler
end

struct SchObserver end

function schelling_headers(::SchObserver)
    return ["PercentSimilar", "PercentUnhappy"]
end

function schelling_values(::SchObserver, world::World)
    stats = get_resource(world, SchStats)
    return Float64[stats.percent_similar, stats.percent_unhappy]
end

function run_schelling(; params::SchParams = SchParams(), observe::Bool = true)
    scheduler = schelling_model(params)
    obs = SchObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, schelling_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, schelling_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
