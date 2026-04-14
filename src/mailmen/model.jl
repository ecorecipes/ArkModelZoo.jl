function mailmen_world(; initial_capacity::Int = 128)
    return World(
        MailmanPosition,
        MailmanState,
        LetterPosition,
        LetterDest,
        LetterState;
        initial_capacity = initial_capacity,
        allow_mutable = true,
    )
end

function mailmen_systems()
    return (
        InitMailmenSystem(),
        MailmenDeliverSystem(),
        MailmenStatsSystem(),
        MailmenTerminationSystem(),
    )
end

function mailmen_model(params::MailmenParams = MailmenParams())
    world = mailmen_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, MailmenStats())
    add_resource!(world, MailmenRegistry())
    scheduler = Scheduler(world, mailmen_systems())
    initialize!(scheduler)
    return scheduler
end

struct MailmenObserver end

function mailmen_headers(::MailmenObserver)
    return ["TotalDist", "NumRemaining"]
end

function mailmen_values(::MailmenObserver, world::World)
    stats = get_resource(world, MailmenStats)
    return Float64[stats.total_dist, Float64(stats.num_remaining)]
end

function run_mailmen(; params::MailmenParams = MailmenParams(), observe::Bool = true)
    scheduler = mailmen_model(params)
    obs = MailmenObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, mailmen_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, mailmen_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
