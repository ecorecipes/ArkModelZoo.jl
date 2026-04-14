function infodiffusion_world(; initial_capacity::Int = 128)
    return World(InfoDiffDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function infodiffusion_systems()
    return (InitInfoDiffSystem(), InfoDiffGoSystem(), InfoDiffTerminationSystem())
end

function infodiffusion_model(params::InfoDiffParams = InfoDiffParams())
    world = infodiffusion_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, InfoDiffNetwork())
    add_resource!(world, InfoDiffStats())
    scheduler = Scheduler(world, infodiffusion_systems())
    initialize!(scheduler)
    return scheduler
end

struct InfoDiffObserver end

function infodiffusion_headers(::InfoDiffObserver)
    return ["NumBelievers", "NumFactcheckers", "NumSusceptibles"]
end

function infodiffusion_values(::InfoDiffObserver, world::World)
    stats = get_resource(world, InfoDiffStats)
    return Float64[stats.num_believers, stats.num_factcheckers, stats.num_susceptibles]
end

function run_infodiffusion(; params::InfoDiffParams = InfoDiffParams(), observe::Bool = true)
    scheduler = infodiffusion_model(params)
    obs = InfoDiffObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, infodiffusion_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, infodiffusion_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
