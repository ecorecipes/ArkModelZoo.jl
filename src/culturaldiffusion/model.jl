function culturaldiffusion_world(; initial_capacity::Int = 64)
    return World(CDDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function culturaldiffusion_systems()
    return (InitCDSystem(), CDGoSystem(), CDTerminationSystem())
end

function culturaldiffusion_model(params::CulturalDiffusionParams = CulturalDiffusionParams())
    world = culturaldiffusion_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, CDState())
    add_resource!(world, CDStats())
    scheduler = Scheduler(world, culturaldiffusion_systems())
    initialize!(scheduler)
    return scheduler
end

struct CDObserver end

function culturaldiffusion_headers(::CDObserver)
    return ["NumIter", "TotalLangsCD"]
end

function culturaldiffusion_values(::CDObserver, world::World)
    stats = get_resource(world, CDStats)
    return Float64[stats.num_iter, stats.total_langs]
end

function run_culturaldiffusion(; params::CulturalDiffusionParams = CulturalDiffusionParams(), observe::Bool = true)
    scheduler = culturaldiffusion_model(params)
    obs = CDObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, culturaldiffusion_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, culturaldiffusion_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
