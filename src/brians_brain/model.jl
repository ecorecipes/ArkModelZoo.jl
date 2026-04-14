function bb_world(; initial_capacity::Int = 64)
    return World(; initial_capacity = initial_capacity, allow_mutable = true)
end

function bb_systems()
    return (
        InitBBSystem(),
        BBGoSystem(),
        BBTerminationSystem(),
    )
end

function bb_model(params::BBParams = BBParams())
    world = bb_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, BBGrid(params.grid_width, params.grid_height))
    add_resource!(world, BBStats())
    scheduler = Scheduler(world, bb_systems())
    initialize!(scheduler)
    return scheduler
end

struct BBObserver end

function bb_headers(::BBObserver)
    return ["Firing", "Refractory", "Dead"]
end

function bb_values(::BBObserver, world::World)
    stats = get_resource(world, BBStats)
    return Float64[Float64(stats.firing_count), Float64(stats.refractory_count),
                    Float64(stats.dead_count)]
end

function run_brians_brain(; params::BBParams = BBParams(), observe::Bool = true)
    scheduler = bb_model(params)
    obs = BBObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, bb_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, bb_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
