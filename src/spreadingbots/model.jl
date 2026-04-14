function spreadingbots_world(; initial_capacity::Int = 128)
    return World(SBotDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function spreadingbots_systems()
    return (InitSBotSystem(), SBotGoSystem(), SBotTerminationSystem())
end

function spreadingbots_model(params::SBotParams = SBotParams())
    world = spreadingbots_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, SBotNetwork())
    add_resource!(world, SBotStats())
    scheduler = Scheduler(world, spreadingbots_systems())
    initialize!(scheduler)
    return scheduler
end

struct SBotObserver end

function spreadingbots_headers(::SBotObserver)
    return ["NumInfected"]
end

function spreadingbots_values(::SBotObserver, world::World)
    stats = get_resource(world, SBotStats)
    return Float64[stats.num_infected]
end

function run_spreadingbots(; params::SBotParams = SBotParams(), observe::Bool = true)
    scheduler = spreadingbots_model(params)
    obs = SBotObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, spreadingbots_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, spreadingbots_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
