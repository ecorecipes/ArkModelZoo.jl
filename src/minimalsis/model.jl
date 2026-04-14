function minimalsis_world(; initial_capacity::Int = 64)
    return World(MSISDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function minimalsis_systems()
    return (InitMSISSystem(), MSISGoSystem(), MSISTerminationSystem())
end

function minimalsis_model(params::MinimalSISParams = MinimalSISParams())
    world = minimalsis_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, MSISState())
    add_resource!(world, MSISStats())
    scheduler = Scheduler(world, minimalsis_systems())
    initialize!(scheduler)
    return scheduler
end

struct MSISObserver end

function minimalsis_headers(::MSISObserver)
    return ["ReproductionNumber", "NewInfected"]
end

function minimalsis_values(::MSISObserver, world::World)
    stats = get_resource(world, MSISStats)
    return Float64[stats.reproduction_number, stats.new_infected]
end

function run_minimalsis(; params::MinimalSISParams = MinimalSISParams(), observe::Bool = true)
    scheduler = minimalsis_model(params)
    obs = MSISObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, minimalsis_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, minimalsis_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
