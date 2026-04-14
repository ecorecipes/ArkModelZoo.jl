function sga_world(; initial_capacity::Int = 256)
    return World(SGABits; initial_capacity = initial_capacity, allow_mutable = true)
end

function sga_systems()
    return (
        InitSGASystem(),
        SGAGoSystem(),
        SGATerminationSystem(),
    )
end

function sga_model(params::SGAParams = SGAParams())
    world = sga_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, SGAStats())
    scheduler = Scheduler(world, sga_systems())
    initialize!(scheduler)
    return scheduler
end

struct SGAObserver end

function sga_headers(::SGAObserver)
    return ["BestFitness", "MeanFitness", "Diversity"]
end

function sga_values(::SGAObserver, world::World)
    stats = get_resource(world, SGAStats)
    return Float64[stats.best_fitness, stats.mean_fitness, stats.diversity]
end

function run_simple_genetic_algorithm(; params::SGAParams = SGAParams(), observe::Bool = true)
    scheduler = sga_model(params)
    obs = SGAObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, sga_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, sga_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
