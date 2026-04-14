function participatorydisinformation_world(; initial_capacity::Int = 128)
    return World(PDisinfoDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function participatorydisinformation_systems()
    return (InitPDisinfoSystem(), PDisinfoGoSystem(), PDisinfoTerminationSystem())
end

function participatorydisinformation_model(params::PDisinfoParams = PDisinfoParams())
    world = participatorydisinformation_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, PDisinfoNetwork())
    add_resource!(world, PDisinfoStats())
    scheduler = Scheduler(world, participatorydisinformation_systems())
    initialize!(scheduler)
    return scheduler
end

struct PDisinfoObserver end

function participatorydisinformation_headers(::PDisinfoObserver)
    return ["EliteHeard", "SocialHeard", "TradedUp", "Created"]
end

function participatorydisinformation_values(::PDisinfoObserver, world::World)
    stats = get_resource(world, PDisinfoStats)
    return Float64[stats.times_heard_from_elites, stats.times_heard_from_social,
                    stats.times_traded_up, stats.times_created_rumor]
end

function run_participatorydisinformation(; params::PDisinfoParams = PDisinfoParams(), observe::Bool = true)
    scheduler = participatorydisinformation_model(params)
    obs = PDisinfoObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, participatorydisinformation_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, participatorydisinformation_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
