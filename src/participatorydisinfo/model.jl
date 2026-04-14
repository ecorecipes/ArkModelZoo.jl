function participatorydisinfo_world(; initial_capacity::Int = 128)
    return World(PDisDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function participatorydisinfo_systems()
    return (InitPDisSystem(), PDisGoSystem(), PDisTerminationSystem())
end

function participatorydisinfo_model(params::PDisParams = PDisParams())
    world = participatorydisinfo_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, PDisNetwork())
    add_resource!(world, PDisStats())
    scheduler = Scheduler(world, participatorydisinfo_systems())
    initialize!(scheduler)
    return scheduler
end

struct PDisObserver end

function participatorydisinfo_headers(::PDisObserver)
    return ["EliteHeard", "SocialHeard", "TradedUp", "Created"]
end

function participatorydisinfo_values(::PDisObserver, world::World)
    stats = get_resource(world, PDisStats)
    return Float64[stats.times_heard_from_elites, stats.times_heard_from_social,
                    stats.times_traded_up, stats.times_created_rumor]
end

function run_participatorydisinfo(; params::PDisParams = PDisParams(), observe::Bool = true)
    scheduler = participatorydisinfo_model(params)
    obs = PDisObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, participatorydisinfo_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, participatorydisinfo_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
