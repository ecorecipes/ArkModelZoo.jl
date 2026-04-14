function languageborders_world(; initial_capacity::Int = 128)
    return World(
        LanguageBordersDummy;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function languageborders_systems()
    return (
        InitLanguageBordersSystem(),
        LanguageBordersUpdateSystem(),
        LanguageBordersTerminationSystem(),
    )
end

function languageborders_model(params::LanguageBordersParams = LanguageBordersParams())
    world = languageborders_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, LanguageBordersGrid(params.grid_width, params.grid_height))
    add_resource!(world, LanguageBordersStats())
    scheduler = Scheduler(world, languageborders_systems())
    initialize!(scheduler)
    return scheduler
end

struct LanguageBordersObserver end

function languageborders_headers(::LanguageBordersObserver)
    return ["AvgLanguage"]
end

function languageborders_values(::LanguageBordersObserver, world::World)
    stats = get_resource(world, LanguageBordersStats)
    return Float64[stats.avg_language]
end

function run_languageborders(; params::LanguageBordersParams = LanguageBordersParams(), observe::Bool = true)
    scheduler = languageborders_model(params)
    obs = LanguageBordersObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, languageborders_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, languageborders_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
