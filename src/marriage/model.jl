function marriage_world(; initial_capacity::Int = 128)
    return World(MarriageDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function marriage_systems()
    return (
        InitMarriageSystem(),
        MarriageProposeSystem(),
        MarriageRejectSystem(),
        MarriageStatsSystem(),
        MarriageTerminationSystem(),
    )
end

function marriage_model(params::MarriageParams = MarriageParams())
    world = marriage_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, MarriageState(params.num_people))
    add_resource!(world, MarriageStats())
    scheduler = Scheduler(world, marriage_systems())
    initialize!(scheduler)
    return scheduler
end

struct MarriageObserver end

function marriage_headers(::MarriageObserver)
    return ["NumBachelors"]
end

function marriage_values(::MarriageObserver, world::World)
    stats = get_resource(world, MarriageStats)
    return Float64[stats.num_bachelors]
end

function run_marriage(; params::MarriageParams = MarriageParams(), observe::Bool = true)
    scheduler = marriage_model(params)
    obs = MarriageObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, marriage_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, marriage_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
