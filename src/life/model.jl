function life_world(; initial_capacity::Int = 128)
    return World(LFDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function life_systems()
    return (
        InitLFSystem(),
        LFGoSystem(),
        LFTerminationSystem(),
    )
end

function life_model(params::LFParams = LFParams())
    world = life_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, LFGrid(params.grid_width, params.grid_height))
    add_resource!(world, LFStats())
    scheduler = Scheduler(world, life_systems())
    initialize!(scheduler)
    return scheduler
end

struct LFObserver end

function life_headers(::LFObserver)
    return ["LivingCount", "Density"]
end

function life_values(::LFObserver, world::World)
    stats = get_resource(world, LFStats)
    return Float64[stats.living_count, stats.density]
end

function run_life(; params::LFParams = LFParams(), observe::Bool = true)
    scheduler = life_model(params)
    obs = LFObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, life_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, life_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
