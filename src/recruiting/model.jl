function recruiting_world(; initial_capacity::Int = 128)
    return World(RecDummy; initial_capacity=initial_capacity, allow_mutable=true)
end

function recruiting_systems()
    return (
        InitRecSystem(),
        RecGoSystem(),
        RecTerminationSystem(),
    )
end

function recruiting_model(params::RecParams = RecParams())
    world = recruiting_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, RecState())
    add_resource!(world, RecStats())
    scheduler = Scheduler(world, recruiting_systems())
    initialize!(scheduler)
    return scheduler
end

struct RecruitingObserver end

function recruiting_headers(::RecruitingObserver)
    return ["recruitpct", "resistpct", "neutralpct"]
end

function recruiting_values(::RecruitingObserver, world::World)
    stats = get_resource(world, RecStats)
    return Float64[stats.recruitpct, stats.resistpct, stats.neutralpct]
end

function run_recruiting(; params::RecParams = RecParams(), observe::Bool = true)
    scheduler = recruiting_model(params)
    obs = RecruitingObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, recruiting_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, recruiting_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
