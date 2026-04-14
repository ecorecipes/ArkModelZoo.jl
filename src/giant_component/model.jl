function gc_world(; initial_capacity::Int = 256)
    return World(GCDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function gc_systems()
    return (InitGCSystem(), GCGoSystem(), GCTerminationSystem())
end

function gc_model(params::GCParams = GCParams())
    world = gc_world()
    add_resource!(world, Tick(0))
    add_resource!(world, Terminate(false))
    add_resource!(world, RNGResource(Xoshiro(params.seed)))
    add_resource!(world, deepcopy(params))
    add_resource!(world, GCNetwork(params.num_nodes))
    add_resource!(world, GCStats())
    scheduler = Scheduler(world, gc_systems())
    initialize!(scheduler)
    return scheduler
end

struct GCObserver end

function gc_headers(::GCObserver)
    return ["GiantComponentSize", "NumEdges", "FractionInGiant", "NumComponents"]
end

function gc_values(::GCObserver, world::World)
    stats = get_resource(world, GCStats)
    return Float64[stats.giant_component_size, stats.num_edges,
                    stats.fraction_in_giant, stats.num_components]
end

function run_giant_component(; params::GCParams = GCParams(), observe::Bool = true)
    scheduler = gc_model(params)
    obs = GCObserver()
    trajectory = Vector{Vector{Float64}}()
    if observe
        push!(trajectory, gc_values(obs, scheduler.world))
    end
    while step!(scheduler)
        if observe
            push!(trajectory, gc_values(obs, scheduler.world))
        end
    end
    return scheduler, trajectory
end
