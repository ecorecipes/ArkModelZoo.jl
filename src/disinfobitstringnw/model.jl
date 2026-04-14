function disinfobitstringnw_world(; initial_capacity::Int = 128)
    return World(DisBitDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function disinfobitstringnw_systems()
    return (InitDisBitSystem(), DisBitGoSystem(), DisBitTerminationSystem())
end

function disinfobitstringnw_model(params::DisBitParams = DisBitParams())
    world = disinfobitstringnw_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, DisBitNetwork())
    add_resource!(world, DisBitStats())
    scheduler = Scheduler(world, disinfobitstringnw_systems())
    initialize!(scheduler)
    return scheduler
end

struct DisBitObserver end

function disinfobitstringnw_headers(::DisBitObserver)
    return ["EliteHeard", "SocialHeard", "TradedUp", "Created"]
end

function disinfobitstringnw_values(::DisBitObserver, world::World)
    stats = get_resource(world, DisBitStats)
    return Float64[stats.times_heard_from_elites, stats.times_heard_from_social,
                    stats.times_traded_up, stats.times_created_rumor]
end

function run_disinfobitstringnw(; params::DisBitParams = DisBitParams(), observe::Bool = true)
    scheduler = disinfobitstringnw_model(params)
    obs = DisBitObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, disinfobitstringnw_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, disinfobitstringnw_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
