function modsocsegregation_world(; initial_capacity::Int = 4096)
    return World(
        ModsocPosition, ModsocColor, ModsocHappiness;
        initial_capacity = initial_capacity, allow_mutable = true,
    )
end

function modsocsegregation_systems()
    return (InitModsocSystem(), ModsocMoveSystem(), ModsocTerminationSystem())
end

function modsocsegregation_model(params::ModsocSegParams = ModsocSegParams())
    world = modsocsegregation_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, ModsocGrid(params.grid_width, params.grid_height))
    add_resource!(world, ModsocStats())
    scheduler = Scheduler(world, modsocsegregation_systems())
    initialize!(scheduler)
    return scheduler
end

struct ModsocSegObserver end

function modsocsegregation_headers(::ModsocSegObserver)
    return ["AverageSimilarity", "Unhappiness"]
end

function modsocsegregation_values(::ModsocSegObserver, world::World)
    stats = get_resource(world, ModsocStats)
    return Float64[stats.average_similarity, stats.unhappiness]
end

function run_modsocsegregation(; params::ModsocSegParams = ModsocSegParams(), observe::Bool = true)
    scheduler = modsocsegregation_model(params)
    obs = ModsocSegObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, modsocsegregation_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, modsocsegregation_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
