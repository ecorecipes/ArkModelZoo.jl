function gc_world(; initial_capacity::Int = 256)
    return World(GCDummy; initial_capacity = initial_capacity, allow_mutable = true)
end

function gc_systems()
    return (InitGCSystem(), GCGoSystem(), GCTerminationSystem())
end

function gc_model(params::GCParams = GCParams())
    world = gc_world()
    _add_standard_resources!(world, params)
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
    return _run_model(gc_model, GCObserver(), gc_values; params, observe)
end
