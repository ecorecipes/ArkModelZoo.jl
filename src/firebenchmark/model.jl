function firebenchmark_world(; initial_capacity::Int = 128)
    return World(FBDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function firebenchmark_systems()
    return (InitFBSystem(), FBStepSystem(), FBTerminationSystem())
end

function firebenchmark_model(params::FBParams = FBParams())
    world = firebenchmark_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, FBGrid(params.grid_width, params.grid_height))
    add_resource!(world, FBStats())
    scheduler = Scheduler(world, firebenchmark_systems())
    initialize!(scheduler)
    return scheduler
end

struct FBObserver end

function firebenchmark_headers(::FBObserver)
    return ["BurnedTrees", "BurningCount"]
end

function firebenchmark_values(::FBObserver, world::World)
    stats = get_resource(world, FBStats)
    return Float64[stats.burned_trees, stats.burning_count]
end

function run_firebenchmark(; params::FBParams = FBParams(), observe::Bool = true)
    scheduler = firebenchmark_model(params)
    obs = FBObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, firebenchmark_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, firebenchmark_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
