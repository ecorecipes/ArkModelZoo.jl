function altruism_world(; initial_capacity::Int = 128)
    return World(ALTDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function altruism_systems()
    return (
        InitALTSystem(),
        ALTGoSystem(),
        ALTTerminationSystem(),
    )
end

function altruism_model(params::ALTParams = ALTParams())
    world = altruism_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, ALTGrid(params.grid_width, params.grid_height))
    add_resource!(world, ALTStats())
    scheduler = Scheduler(world, altruism_systems())
    initialize!(scheduler)
    return scheduler
end

struct ALTObserver end

function altruism_headers(::ALTObserver)
    return ["NumAltruists", "NumSelfish", "NumHarsh"]
end

function altruism_values(::ALTObserver, world::World)
    stats = get_resource(world, ALTStats)
    return Float64[stats.num_altruists, stats.num_selfish, stats.num_harsh]
end

function run_altruism(; params::ALTParams = ALTParams(), observe::Bool = true)
    scheduler = altruism_model(params)
    obs = ALTObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, altruism_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, altruism_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
